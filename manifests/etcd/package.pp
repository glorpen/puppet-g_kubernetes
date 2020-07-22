class g_kubernetes::etcd::package {

  $config_dir = $::g_kubernetes::etcd::config_dir
  $data_dir = $::g_kubernetes::etcd::data_dir
  $ssl_dir = $::g_kubernetes::etcd::ssl_dir
  $ensure = $::g_kubernetes::etcd::ensure
  $version = $::g_kubernetes::etcd::package_version
  $checksum = $::g_kubernetes::etcd::package_checksum

  $ensure_directory = $ensure?{
    'present' => 'directory',
    default => 'absent'
  }

  $user = 'etcd'

  $checksums = {
    '3.4.10' => '621172ab3b8e122d174507406e98d1cb75dcbb77'
  }

  include ::stdlib

  $_checksum = pick_default($checksum, $checksums[$version])

  file { $config_dir:
    ensure => $ensure_directory,
    owner  => $user,
    group  => $user
  }
  file { $ssl_dir:
    ensure => $ensure_directory,
    owner  => $user,
    group  => $user
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

  file { ['/opt/etcd', '/opt/etcd/share', '/opt/etcd/bin']:
    ensure       => directory,
    recurselimit => 1,
    force        => true,
    purge        => true
  }

  $pkg_name = "etcd-v${version}-linux-amd64"
  $archive = "/opt/etcd/share/etcd-${version}.tar.gz"
  archive { $archive:
    ensure        => present,
    source        => "https://github.com/etcd-io/etcd/releases/download/v${version}/${pkg_name}.tar.gz",
    extract       => true,
    extract_path  => '/opt/etcd/share/',
    user          => 0,
    group         => 0,
    checksum      => $_checksum,
    checksum_type => 'sha1',
    creates       => "/opt/etcd/share/${pkg_name}/etcd",
    cleanup       => true,
  }

  ['etcdctl', 'etcd'].each | $f | {
    file { "/opt/etcd/bin/${f}":
      ensure  => 'symlink',
      require => Archive[$archive],
      target  => "/opt/etcd/share/${pkg_name}/${f}"
    }
  }
}
