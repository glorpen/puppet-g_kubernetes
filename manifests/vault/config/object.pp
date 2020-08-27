define g_kubernetes::vault::config::object (
  Hash $config,
  Enum['present', 'absent'] $ensure = 'present'
){
  include ::stdlib

  file { "${::g_kubernetes::vault::config::conf_d_dir}/${title}.json":
    ensure  => $ensure,
    content => to_json_pretty($config),
    require => Class[::g_kubernetes::vault::package],
    notify  => Class[::g_kubernetes::vault::service]
  }
}
