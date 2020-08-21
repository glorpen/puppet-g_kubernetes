class g_kubernetes::vault::service {
  $ensure = $::g_kubernetes::vault::ensure

  $service_ensure = $ensure?{'present' => 'running', default => false}
  $service_enable = $ensure?{'present' => true, default => false}

  service { 'vault':
    ensure => $service_ensure,
    enable => $service_enable
  }

  $_bin_path = "${::g_kubernetes::vault::package::bin_dir}/etcd"

  systemd::unit_file { 'vault.service':
    ensure  => $ensure,
    content => epp('g_kubernetes/vault/systemd-unit.epp', {
      'data_dir'    => $::g_kubernetes::etcd::data_dir,
      'user'        => $::g_kubernetes::etcd::user,
      'bin_path'    => $_bin_path,
      'config_file' => $::g_kubernetes::etcd::config_file
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
