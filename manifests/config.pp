# This class exists to coordinate all configuration related actions,
# functionality and logical units in a central place.
#
# It is not intended to be used directly by external resources like node
# definitions or other modules.
#
# @example importing this class into other classes to use its functionality:
#   class { 'elasticsearch_legacy::config': }
#
# @author Richard Pijnenburg <richard.pijnenburg@elasticsearch.com>
# @author Tyler Langlois <tyler.langlois@elastic.co>
#
class elasticsearch_legacy::config {

  #### Configuration

  Exec {
    path => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    cwd  => '/',
  }

  if ( $elasticsearch_legacy::ensure == 'present' ) {

    file {
      $elasticsearch_legacy::configdir:
        ensure => 'directory',
        group  => $elasticsearch_legacy::elasticsearch_group,
        owner  => $elasticsearch_legacy::elasticsearch_user,
        mode   => '0755';
      $elasticsearch_legacy::datadir:
        ensure => 'directory',
        group  => $elasticsearch_legacy::elasticsearch_group,
        owner  => $elasticsearch_legacy::elasticsearch_user;
      $elasticsearch_legacy::logdir:
        ensure  => 'directory',
        group   => undef,
        owner   => $elasticsearch_legacy::elasticsearch_user,
        mode    => '0755',
        recurse => true;
      $elasticsearch_legacy::plugindir:
        ensure => 'directory',
        group  => $elasticsearch_legacy::elasticsearch_group,
        owner  => $elasticsearch_legacy::elasticsearch_user,
        mode   => 'o+Xr';
      "${elasticsearch_legacy::homedir}/lib":
        ensure  => 'directory',
        group   => '0',
        owner   => 'root',
        recurse => true;
      $elasticsearch_legacy::homedir:
        ensure => 'directory',
        group  => $elasticsearch_legacy::elasticsearch_group,
        owner  => $elasticsearch_legacy::elasticsearch_user;
      "${elasticsearch_legacy::homedir}/templates_import":
        ensure => 'directory',
        group  => $elasticsearch_legacy::elasticsearch_group,
        owner  => $elasticsearch_legacy::elasticsearch_user,
        mode   => '0755';
      "${elasticsearch_legacy::homedir}/scripts":
        ensure => 'directory',
        group  => $elasticsearch_legacy::elasticsearch_group,
        owner  => $elasticsearch_legacy::elasticsearch_user,
        mode   => '0755';
      '/etc/elasticsearch/elasticsearch.yml':
        ensure => 'absent';
      '/etc/elasticsearch/jvm.options':
        ensure => 'absent';
      '/etc/elasticsearch/logging.yml':
        ensure => 'absent';
      '/etc/elasticsearch/log4j2.properties':
        ensure => 'absent';
      '/etc/init.d/elasticsearch':
        ensure => 'absent';
    }

    if $elasticsearch_legacy::pid_dir {
      file { $elasticsearch_legacy::pid_dir:
        ensure  => 'directory',
        group   => undef,
        owner   => $elasticsearch_legacy::elasticsearch_user,
        recurse => true,
      }

      if ($elasticsearch_legacy::service_provider == 'systemd') {
        $group = $elasticsearch_legacy::elasticsearch_group
        $user = $elasticsearch_legacy::elasticsearch_user
        $pid_dir = $elasticsearch_legacy::pid_dir

        file { '/usr/lib/tmpfiles.d/elasticsearch.conf':
          ensure  => 'file',
          content => template("${module_name}/usr/lib/tmpfiles.d/elasticsearch.conf.erb"),
          group   => '0',
          owner   => 'root',
        }
      }
    }

    if ($elasticsearch_legacy::service_provider == 'systemd') {
      # Mask default unit (from package)
      service { 'elasticsearch' :
        enable => 'mask',
      }
    }

    if $elasticsearch_legacy::defaults_location {
      augeas { "${elasticsearch_legacy::defaults_location}/elasticsearch":
        incl    => "${elasticsearch_legacy::defaults_location}/elasticsearch",
        lens    => 'Shellvars.lns',
        changes => [
          'rm CONF_FILE',
          'rm CONF_DIR',
          'rm ES_PATH_CONF',
        ],
      }
    }

    if $::elasticsearch_legacy::security_plugin != undef and ($::elasticsearch_legacy::security_plugin in ['shield', 'x-pack']) {
      file { "/etc/elasticsearch/${::elasticsearch_legacy::security_plugin}" :
        ensure => 'directory',
      }
    }

    # Define logging config file for the in-use security plugin
    if $::elasticsearch_legacy::security_logging_content != undef or $::elasticsearch_legacy::security_logging_source != undef {
      if $::elasticsearch_legacy::security_plugin == undef or ! ($::elasticsearch_legacy::security_plugin in ['shield', 'x-pack']) {
        fail("\"${::elasticsearch_legacy::security_plugin}\" is not a valid security_plugin parameter value")
      }

      $_security_logging_file = $::elasticsearch_legacy::security_plugin ? {
        'shield' => 'logging.yml',
        default => 'log4j2.properties'
      }

      file { "/etc/elasticsearch/${::elasticsearch_legacy::security_plugin}/${_security_logging_file}" :
        content => $::elasticsearch_legacy::security_logging_content,
        source  => $::elasticsearch_legacy::security_logging_source,
      }
    }

  } elsif ( $elasticsearch_legacy::ensure == 'absent' ) {

    file { $elasticsearch_legacy::plugindir:
      ensure => 'absent',
      force  => true,
      backup => false,
    }

    file { "${elasticsearch_legacy::configdir}/jvm.options":
      ensure => 'absent',
    }

  }

}
