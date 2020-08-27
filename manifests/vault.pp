# @summary Configures Hashicorp Vault with Etcd as backend
# 
# @param package_checksum
#   Vault package checksum (sha1)
# @param export_etcd_client
#   Exports g_kubernetes::etcd::node::client resource to mark this node as etcd client
# @param api_advertise_host
#   Optional address to use when advertising api address to clients. If not provided, first ip from api_side will be used.
class g_kubernetes::vault (
  Enum['present', 'absent'] $ensure = 'present',
  String $package_version = '1.5.0',
  Optional[String] $package_checksum = undef,
  Optional[Array[String]] $etcd_urls = undef,
  Boolean $export_etcd_client = true,
  Stdlib::AbsolutePath $config_dir = '/etc/vault',
  String $user = 'vault',
  Optional[Stdlib::Host] $api_advertise_host = undef,

  Integer $peer_port = 8201,
  G_server::Side $peer_side = 'internal',
  Integer $api_port = 8200,
  G_server::Side $api_side = 'internal',

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
  $api_ips = g_kubernetes::get_ips($api_side)

  if defined(Class['g_kubernetes::vault::agent']) {
    fail('g_kubernetes::vault::agent should be used after g_kubernetes::vault')
  }

  class{ 'g_kubernetes::vault::package':
    ensure           => $ensure,
    package_version  => $package_version,
    package_checksum => $package_checksum,
    disable_mlock    => $disable_mlock,
    user             => $user
  }
  include ::g_kubernetes::vault::config
  include ::g_kubernetes::vault::firewall
  include ::g_kubernetes::vault::service

  if $ensure == 'present' {
    @@g_kubernetes::vault::peer { $::trusted['certname']:
      ips    => $peer_ips
    }

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
