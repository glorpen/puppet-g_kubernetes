class g_kubernetes::vault::package {
  $ensure = $::g_kubernetes::vault::ensure
  $version = $::g_kubernetes::vault::package_version
  $checksum = $::g_kubernetes::vault::package_checksum
  $disable_mlock = $::g_kubernetes::vault::disable_mlock
  $user = $::g_kubernetes::vault::user

  include ::stdlib

  $checksums = {
    '1.5.0' => 'e67df7d01d66eace1b12f314d76a0e1b1f67d028'
  }
  $ensure_directory = $ensure?{
    'present' => 'directory',
    default   => 'absent'
  }

  $opt_dir = '/opt/vault'
  $bin_dir = "${opt_dir}/bin"
  $share_dir = "${opt_dir}/share"
  $vault_bin = "${bin_dir}/vault"

  group { $user:
    ensure => $ensure,
    system => true
  }
  user { $user:
    ensure  => $ensure,
    home    => '/dev/null',
    system  => true,
    shell   => '/sbin/nologin',
    comment => 'vault user managed by puppet',
    gid     => $user
  }

  file { [$opt_dir, $share_dir, $bin_dir]:
    ensure       => $ensure_directory,
    purge        => true,
    force        => true,
    recurse      => true,
    recurselimit => 1,
  }

  $_checksum = pick_default($checksum, $checksums[$version])
  $_arch = $facts['architecture']?{
    /(x86_64|amd64)/ => 'amd64',
    'i386'           => '386',
    /^arm.*/         => 'arm'
  }

  $pkg_name = "vault_${version}_linux_${_arch}"
  $archive = "${share_dir}/vault-${version}.zip"
  $vault_source_bin = "${share_dir}/${pkg_name}/vault"

  if $ensure == 'present' {
    archive { $archive:
      ensure        => $ensure,
      source        => "https://releases.hashicorp.com/vault/${version}/${pkg_name}.zip",
      extract       => true,
      extract_path  => $share_dir,
      user          => 0,
      group         => 0,
      checksum      => $_checksum,
      checksum_type => 'sha1',
      creates       => $vault_source_bin,
      cleanup       => true,
    }
    ->file { "${share_dir}/${pkg_name}":
      ensure => directory
    }

    $ensure_mlock = $disable_mlock?{
      true    => 'present',
      default => 'absent'
    }
    file_capability { 'g_kubernetes::vault mlock':
      ensure     => $ensure_mlock,
      file       => $vault_source_bin,
      capability => 'cap_ipc_lock=ep',
      subscribe  => Archive[$archive],
      notify     => Service['vault']
    }

    file { $vault_bin:
      ensure  => 'symlink',
      require => Archive[$archive],
      target  => $vault_source_bin
    }

    User[$user]
    ->Group[$user]
  }
}
