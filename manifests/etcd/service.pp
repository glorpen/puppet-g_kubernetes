class g_kubernetes::etcd::service {
  $ensure = $::g_kubernetes::etcd::ensure

  service { 'etcd':
    ensure => $ensure?{'present' => 'running', default => false},
    enable => $ensure?{'present' => true, default => false}
  }
}
