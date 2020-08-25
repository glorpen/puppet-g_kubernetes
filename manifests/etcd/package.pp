class g_kubernetes::etcd::package {

  $config_dir = $::g_kubernetes::etcd::config_dir
  $data_dir = $::g_kubernetes::etcd::data_dir
  $ssl_dir = $::g_kubernetes::etcd::ssl_dir
  $ensure = $::g_kubernetes::etcd::ensure
  $version = $::g_kubernetes::etcd::package_version
  $checksum = $::g_kubernetes::etcd::package_checksum
  $user = $::g_kubernetes::etcd::user

  $bin_dir = '/opt/etcd/bin'

  $ensure_directory = $ensure?{
    'present' => 'directory',
    default => 'absent'
  }


  $checksums = {
    '3.4.10' => '621172ab3b8e122d174507406e98d1cb75dcbb77'
  }

  include ::stdlib

  $_checksum = pick_default($checksum, $checksums[$version])

  file { [$ssl_dir, $config_dir]:
    ensure => $ensure_directory,
    owner  => $user,
    group  => $user,
    force  => true,
    purge  => true
  }

  if $ensure == 'present' {
    File[$config_dir]->File[$ssl_dir]
  } else {
    File[$ssl_dir]->File[$config_dir]
  }

  group { $user:
    ensure => $ensure,
    system => true
  }
  user { $user:
    ensure  => $ensure,
    home    => $data_dir,
    system  => true,
    shell   => '/sbin/nologin',
    comment => 'etcd user managed by puppet',
    gid     => $user
  }

  if $ensure == 'absent' {
    User[$user]
    ->Group[$user]
  }

  file { $data_dir:
    ensure => $ensure_directory,
    force  => true,
    owner  => $user,
    group  => $user,
    mode   => 'u=rwx,go='
  }

  file { ['/opt/etcd', '/opt/etcd/share', $bin_dir]:
    ensure       => $ensure_directory,
    recurse      => true,
    recurselimit => 1,
    force        => true,
    purge        => true
  }

  ensure_packages(['tar', 'gzip'])

  $pkg_name = "etcd-v${version}-linux-amd64"
  $archive = "/opt/etcd/share/etcd-${version}.tar.gz"
  if $ensure == 'present' {
    archive { $archive:
      source        => "https://github.com/etcd-io/etcd/releases/download/v${version}/${pkg_name}.tar.gz",
      extract       => true,
      extract_path  => '/opt/etcd/share/',
      user          => 0,
      group         => 0,
      checksum      => $_checksum,
      checksum_type => 'sha1',
      creates       => "/opt/etcd/share/${pkg_name}/etcd",
      cleanup       => true,
      require       => [Package['tar'], Package['gzip']]
    }
    ->file { "/opt/etcd/share/${pkg_name}":
      ensure => directory
    }
    ['etcdctl', 'etcd'].each | $f | {
      file { "${bin_dir}/${f}":
        ensure  => 'symlink',
        require => Archive[$archive],
        target  => "/opt/etcd/share/${pkg_name}/${f}"
      }
    }
  }

}
