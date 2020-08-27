class g_kubernetes::vault::agent::service {
  $ensure = $::g_kubernetes::vault::agent::ensure

  $service_ensure = $ensure?{'present' => 'running', default => false}
  $service_enable = $ensure?{'present' => true, default => false}

  service { 'vault-agent':
    ensure => $service_ensure,
    enable => $service_enable
  }

  systemd::unit_file { 'vault-agent.service':
    ensure  => $ensure,
    content => epp('g_kubernetes/vault/agent-systemd-unit.epp', {
      'user'       => 'root',
      'bin_path'   => $::g_kubernetes::vault::package::vault_bin,
      'config_dir' => $::g_kubernetes::vault::agent::config_file
    }),
  }

  if $ensure == 'present' {
    Systemd::Unit_file['vault-agent.service']
    ~>Service['vault-agent']
  } else {
    Service['vault-agent']
    ->Systemd::Unit_file['vault-agent.service']
  }
}
