define java::setup (
  $ensure        = 'present',
  $source        = undef,
  $deploymentdir = '/opt/oracle-java',
  $pathfile      = '/etc/bashrc',
  $cachedir      = "/var/run/puppet/java_setup_working-${name}",
  $user          = undef) {
  # We support only Debian, RedHat and Suse
  case $::osfamily {
    Debian  : { $supported = true }
    RedHat  : { $supported = true }
    Suse    : { $supported = true }
    default : { fail("The ${module_name} module is not supported on ${::osfamily} based systems") }
  }

  # Validate parameters
  if ($source == undef) {
    fail('source parameter must be set')
  }

  if ($user == undef) {
    fail('user parameter must be set')
  }

  # Validate source is .gz or .tar.gz
  if !(('.tar.gz' in $source) or ('.gz' in $source) or ('.bin' in $source)) {
    fail('source must be either .tar.gz or .gz or .bin')
  }

  # Validate input values for $ensure
  if !($ensure in ['present', 'absent']) {
    fail('ensure must either be present or absent')
  }

  if ($caller_module_name == undef) {
    $mod_name = $module_name
  } else {
    $mod_name = $caller_module_name
  }

  # Resource default for Exec
  Exec {
    path => ['/sbin', '/bin', '/usr/sbin', '/usr/bin'], }

  # When ensure => present
  if ($ensure == 'present') {
    exec { "create-${cachedir}":
      cwd     => '/',
      command => "mkdir -p ${cachedir}",
      creates => $cachedir,
    }

    file { "${cachedir}/${source}":
      source  => "puppet:///modules/${mod_name}/${source}",
      mode    => '711',
      require => Exec["create-${cachedir}"],
    }

    if ('.bin' in $source) {
      exec { "extract_java-${name}":
        cwd     => $cachedir,
        command => "mkdir extracted; cd extracted ;  ../*.bin  <> echo '\n\n' -d extracted && touch ${cachedir}/.java_extracted",
        creates => "${cachedir}/.java_extracted",
        # in case of a bin archive, we get a return code of 1 from unzip. This is ok
        returns => [0, 1],
        require => File["${cachedir}/${source}"],
      }
    } else {
      exec { "extract_java-${name}":
        cwd     => $cachedir,
        command => "mkdir extracted; tar -C extracted -xzf *.gz && touch ${cachedir}/.java_extracted",
        creates => "${cachedir}/.java_extracted",
        require => File["${cachedir}/${source}"],
      }
    }

    exec { "create_target-${name}":
      cwd     => '/',
      command => "mkdir -p ${deploymentdir}",
      creates => $deploymentdir,
      require => Exec["extract_java-${name}"],
    }

    exec { "move_java-${name}":
      cwd     => "${cachedir}/extracted",
      command => "cp -r */* ${deploymentdir}/ && chown -R ${user}:${user} ${deploymentdir} && touch ${deploymentdir}/.puppet_java_${name}_deployed",
      creates => "${deploymentdir}/.puppet_java_${name}_deployed",
      require => Exec["create_target-${name}"],
    }

    exec { "set_java_home-${name}":
      cwd     => '/',
      command => "echo 'export JAVA_HOME=${deploymentdir}' >> ${pathfile}",
      unless  => "grep 'JAVA_HOME=${deploymentdir}' ${pathfile}",
      require => Exec["move_java-${name}"],
    }

    exec { "update_path-${name}":
      cwd     => '/',
      command => "echo 'export PATH=\$PATH:\$JAVA_HOME/bin' >> ${pathfile}",
      unless  => "grep 'export PATH=\$PATH:\$JAVA_HOME/bin' ${pathfile}",
      require => Exec["set_java_home-${name}"],
    }

    exec { "update_classpath-${name}":
      cwd     => '/',
      command => "echo 'export CLASSPATH=\$JAVA_HOME/lib/classes.zip' >> ${pathfile}",
      unless  => "grep 'export CLASSPATH=\$JAVA_HOME/lib/classes.zip' ${pathfile}",
      require => Exec["set_java_home-${name}"],
    }
  } else {
    file { $deploymentdir:
      ensure  => absent,
      recurse => true,
      force   => true,
    }

    file { $cachedir:
      ensure  => absent,
      recurse => true,
      force   => true,
    }
  }
}
