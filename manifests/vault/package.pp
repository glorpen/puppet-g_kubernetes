class g_kubernetes::vault::package {
  $ensure = $::g_kubernetes::vault::ensure
  $version = $::g_kubernetes::vault::package_version
  $checksum = $::g_kubernetes::vault::package_checksum
  $disable_mlock = $::g_kubernetes::vault::disable_mlock

  $checksums = {
    '1.5.0' => 'e67df7d01d66eace1b12f314d76a0e1b1f67d028'
  }

  $bin_dir = '/opt/vault/bin'

  $ensure_symlink = $ensure?{
    'present' => 'symlink',
    default => 'absent'
  }

  include ::stdlib

  $_checksum = pick_default($checksum, $checksums[$version])
  $_arch = $facts['architecture']?{
    /(x86_64|amd64)/ => 'amd64',
    'i386'           => '386',
    /^arm.*/         => 'arm'
  }

  $pkg_name = "vault_${version}_linux_${_arch}"
  $archive = "/opt/vault/share/vault-${version}.zip"
  $vault_bin = "/opt/vault/share/${pkg_name}/vault"
  archive { $archive:
    ensure        => $ensure,
    source        => "https://releases.hashicorp.com/vault/${version}/${pkg_name}.zip",
    extract       => true,
    extract_path  => '/opt/vault/share/',
    user          => 0,
    group         => 0,
    checksum      => $_checksum,
    checksum_type => 'sha1',
    creates       => "/opt/vault/share/${pkg_name}/vault",
    cleanup       => true,
  }
  ->file { "/opt/vault/share/${pkg_name}":
    ensure => directory
  }

  if $ensure == 'present' {
    $ensure_mlock = $disable_mlock?{
      true    => 'present',
      default => 'absent'
    }
    file_capability { 'g_kubernetes::vault mlock':
      ensure     => $ensure_mlock,
      file       => $vault_bin,
      capability => 'cap_ipc_lock=ep',
      subscribe  => Archive[$archive],
      notify     => Service['vault']
    }
  }

  file { "${bin_dir}/vault":
    ensure  => $ensure_symlink,
    require => Archive[$archive],
    target  => $vault_bin
  }
}