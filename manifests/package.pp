# This class exists to coordinate all software package management related
# actions, functionality and logical units in a central place.
#
# It is not intended to be used directly by external resources like node
# definitions or other modules.
#
# @example importing this class by other classes to use its functionality:
#   class { 'elasticsearch_legacy::package': }
#
# @author Richard Pijnenburg <richard.pijnenburg@elasticsearch.com>
# @author Tyler Langlois <tyler.langlois@elastic.co>
#
class elasticsearch_legacy::package {

  Exec {
    path      => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    cwd       => '/',
    tries     => 3,
    try_sleep => 10,
  }

  if $elasticsearch_legacy::ensure == 'present' {

    if $elasticsearch_legacy::restart_package_change {
      Package[$elasticsearch_legacy::package_name] ~> Elasticsearch_legacy::Service <| |>
    }
    Package[$elasticsearch_legacy::package_name] ~> Exec['remove_plugin_dir']

    # Create directory to place the package file
    $package_dir = $elasticsearch_legacy::package_dir
    exec { 'create_package_dir_elasticsearch':
      cwd     => '/',
      path    => ['/usr/bin', '/bin'],
      command => "mkdir -p ${package_dir}",
      creates => $package_dir,
    }

    file { $package_dir:
      ensure  => 'directory',
      purge   => $elasticsearch_legacy::purge_package_dir,
      force   => $elasticsearch_legacy::purge_package_dir,
      backup  => false,
      require => Exec['create_package_dir_elasticsearch'],
    }

    # Check if we want to install a specific version or not
    if $elasticsearch_legacy::version == false {

      $package_ensure = $elasticsearch_legacy::autoupgrade ? {
        true  => 'latest',
        false => 'present',
      }

    } else {

      # install specific version
      $package_ensure = $elasticsearch_legacy::pkg_version

    }

    # action
    if ($elasticsearch_legacy::package_url != undef) {

      case $elasticsearch_legacy::package_provider {
        'package': { $before = Package[$elasticsearch_legacy::package_name]  }
        default:   { fail("software provider \"${elasticsearch_legacy::package_provider}\".") }
      }


      $filename_array = split($elasticsearch_legacy::package_url, '/')
      $basefilename = $filename_array[-1]

      $source_array = split($elasticsearch_legacy::package_url, ':')
      $protocol_type = $source_array[0]

      $ext_array = split($basefilename, '\.')
      $ext = $ext_array[-1]

      $pkg_source = "${package_dir}/${basefilename}"

      case $protocol_type {

        'puppet': {

          file { $pkg_source:
            ensure  => file,
            source  => $elasticsearch_legacy::package_url,
            require => File[$package_dir],
            backup  => false,
            before  => $before,
          }

        }
        'ftp', 'https', 'http': {

          if $elasticsearch_legacy::proxy_url != undef {
            $exec_environment = [
              'use_proxy=yes',
              "http_proxy=${elasticsearch_legacy::proxy_url}",
              "https_proxy=${elasticsearch_legacy::proxy_url}",
            ]
          } else {
            $exec_environment = []
          }

          case $elasticsearch_legacy::download_tool {
            String: {
              exec { 'download_package_elasticsearch':
                command     => "${elasticsearch_legacy::download_tool} ${pkg_source} ${elasticsearch_legacy::package_url} 2> /dev/null",
                creates     => $pkg_source,
                environment => $exec_environment,
                timeout     => $elasticsearch_legacy::package_dl_timeout,
                require     => File[$package_dir],
                before      => $before,
              }
            }
            default: {
              fail("no \$elasticsearch_legacy::download_tool defined for ${facts['os']['family']}")
            }
          }

        }
        'file': {

          $source_path = $source_array[1]
          file { $pkg_source:
            ensure  => file,
            source  => $source_path,
            require => File[$package_dir],
            backup  => false,
            before  => $before,
          }

        }
        default: {
          fail("Protocol must be puppet, file, http, https, or ftp. You have given \"${protocol_type}\"")
        }
      }

      if ($elasticsearch_legacy::package_provider == 'package') {

        case $ext {
          'deb':   { Package { provider => 'dpkg', source => $pkg_source } }
          'rpm':   { Package { provider => 'rpm', source => $pkg_source } }
          default: { fail("Unknown file extention \"${ext}\".") }
        }

      }

    }

  # Package removal
  } else {

    if ($facts['os']['family'] == 'Suse') {
      Package {
        provider  => 'rpm',
      }
      $package_ensure = 'absent'
    } else {
      $package_ensure = 'purged'
    }

  }

  if ($elasticsearch_legacy::package_provider == 'package') {

    package { $elasticsearch_legacy::package_name:
      ensure => $package_ensure,
    }

    exec { 'remove_plugin_dir':
      refreshonly => true,
      command     => "rm -rf ${elasticsearch_legacy::plugindir}",
    }


  } else {
    fail("\"${elasticsearch_legacy::package_provider}\" is not supported")
  }

}
