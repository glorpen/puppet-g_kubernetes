class g_kubernetes::vault::service {
  $ensure = $::g_kubernetes::vault::ensure

  $service_ensure = $ensure?{'present' => 'running', default => false}
  $service_enable = $ensure?{'present' => true, default => false}

  service { 'vault':
    ensure => $service_ensure,
    enable => $service_enable
  }

  systemd::unit_file { 'vault.service':
    ensure  => $ensure,
    content => epp('g_kubernetes/vault/systemd-unit.epp', {
      'user'       => $::g_kubernetes::vault::user,
      'bin_path'   => $::g_kubernetes::vault::package::vault_bin,
      'config_dir' => $::g_kubernetes::vault::conf_d_dir
    }),
  }

  if $ensure == 'present' {
    Systemd::Unit_file['vault.service']
    ~>Service['vault']
  } else {
    Service['vault']
    ->Systemd::Unit_file['vault.service']
  }
}
