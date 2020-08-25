class g_kubernetes::vault (
  Enum['present', 'absent'] $ensure = 'present',
  String $package_version = '1.5.0',
  Optional[String] $package_checksum = undef,
  Optional[Array[String]] $etcd_urls = undef,
  Stdlib::AbsolutePath $config_dir = '/etc/vault',
  String $user = 'vault',

  Integer $peer_port = 8201,
  G_server::Side $peer_side = 'internal',
  Integer $api_port = 8200,
  G_server::Side $api_side = 'internal',
  Optional[Stdlib::Host] $cluster_addr = undef,

  Boolean $disable_mlock = false,
  String $log_level = 'warn',
  G_kubernetes::Duration $default_lease_ttl = '768h',
  G_kubernetes::Duration $max_lease_ttl = '768h',
  G_kubernetes::Duration $default_max_request_duration = '90s',

  Optional[G_kubernetes::CertSource] $node_cert = undef,
  Optional[G_kubernetes::CertSource] $node_key = undef,
  Optional[G_kubernetes::CertSource] $client_ca_cert = undef,

  Enum['interface', 'peer', 'none'] $peer_firewall_mode = 'interface',
  Enum['interface', 'client', 'none'] $api_firewall_mode = 'interface',
) {
  $ssl_dir = "${config_dir}/ssl"
  $conf_d_dir = "${config_dir}/conf.d"

  $peer_ips = g_kubernetes::get_ips($peer_side)

  @@g_kubernetes::vault::peer { $::trusted['certname']:
    ensure => $ensure,
    ips    => $peer_ips
  }

  include ::g_kubernetes::vault::package
  include ::g_kubernetes::vault::config
  include ::g_kubernetes::vault::firewall
  include ::g_kubernetes::vault::service

  if $ensure == 'present' {
    Class[::g_kubernetes::vault::package]
    ->Class[::g_kubernetes::vault::config]
    ->Class[::g_kubernetes::vault::firewall]
    ~>Class[::g_kubernetes::vault::service]

  } else {
    Class[::g_kubernetes::vault::service]
    ->Class[::g_kubernetes::vault::config]
    ->Class[::g_kubernetes::vault::package]
  }
}
