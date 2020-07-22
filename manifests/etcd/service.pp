class g_kubernetes::etcd::service {
  $ensure = $::g_kubernetes::etcd::ensure

  $service_ensure = $ensure?{'present' => 'running', default => false}
  $service_enable = $ensure?{'present' => true, default => false}

  service { 'etcd':
    ensure => $service_ensure,
    enable => $service_enable
  }

  if $::g_kubernetes::etcd::package_manage {
    $_bin_path = "${::g_kubernetes::etcd::package::bin_dir}/etcd"
  } else {
    $_bin_path = $::g_kubernetes::etcd::unmanaged_etcd_bin
  }

  systemd::unit_file { 'etcd.service':
    ensure  => $ensure,
    content => epp('templates/etcd/systemd-unit.epp', {
      'data_dir'    => $::g_kubernetes::etcd::data_dir,
      'user'        => $::g_kubernetes::etcd::user,
      'bin_path'    => $_bin_path,
      'config_file' => $::g_kubernetes::etcd::config_file
    }),
  }

  if $ensure == 'present' {
    Systemd::Unit_file['etcd.service']
    ~>Service['etcd']
  } else {
    Service['etcd']
    ->Systemd::Unit_file['etcd.service']
  }
}
