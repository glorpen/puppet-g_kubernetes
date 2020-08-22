# @summary Configures ETCD
#
# @param firewall_mode
#   Open swarm ports to whole cluster_iface ('interface') or for each other peer node separately ('peer').
#
class g_kubernetes::etcd(
  Optional[Hash[String, Stdlib::Host]] $servers = undef,
  Integer $client_port = 2379,
  G_server::Side $client_side = 'internal',
  Enum['interface', 'node', 'none'] $client_firewall_mode = 'interface',
  Integer $peer_port = 2380,
  G_server::Side $peer_side = 'internal',
  Enum['interface', 'node', 'none'] $peer_firewall_mode = 'interface',

  String $data_dir = '/var/lib/etcd',
  String $config_dir = '/etc/etcd',
  # Optional[String] $wal_dir = undef,
  Hash $options = {},
  Enum['present', 'absent'] $ensure = 'present',

  String $user = 'etcd',
  Optional[Stdlib::AbsolutePath] $unmanaged_etcd_bin = undef,

  Boolean $package_manage = true,
  String $package_version = '3.4.10',
  Optional[String] $package_checksum = undef,
  Boolean $service_manage = true,

  Optional[G_kubernetes::CertSource] $client_ca_cert = undef,
  Optional[G_kubernetes::CertSource] $client_cert = undef,
  Optional[G_kubernetes::CertSource] $client_key = undef,
  Boolean $client_cert_auth = false,
  Boolean $client_auto_tls = false,

  Optional[G_kubernetes::CertSource] $peer_ca_cert = undef,
  Optional[G_kubernetes::CertSource] $peer_cert = undef,
  Optional[G_kubernetes::CertSource] $peer_key = undef,
  Boolean $peer_cert_auth = false,
  Boolean $peer_auto_tls = false
) {
  include ::g_server

  # don't use system packages,
  # create user etcd and download given version from vendor

  $ssl_dir = "${config_dir}/ssl"
  $config_file = "${config_dir}/etc.yaml"


  if $client_auto_tls or $client_ca_cert {
    $client_scheme = 'https'
  } else {
    $client_scheme = 'http'
  }

  if $peer_auto_tls or $peer_ca_cert {
    $peer_scheme = 'https'
  } else {
    $peer_scheme = 'http'
  }

  $_ips = ['peer', 'client'].map | $type | {
    $side = getvar("${type}_side")
    flatten(g_server::get_interfaces($side).map | $iface | {
      $_network_info = $::facts['networking']['interfaces'][$iface]
      ['', '6'].map |$t| {
        $_network_info["bindings${t}"].map | $c | {
          $c['address']
        }.filter | $i | {
          $i !~ G_kubernetes::Ipv6LinkLocal
        }
      }
    })
  }
  $peer_ips = $_ips[0]
  $client_ips = $_ips[1]

  if $ensure == 'present' {
    @@g_kubernetes::etcd::node::peer { $::trusted['certname']:
      ips    => $peer_ips,
      port   => $peer_port,
      scheme => $peer_scheme,
    }
  }

  if $package_manage {
    include ::g_kubernetes::etcd::package
  }

  if $service_manage {
    include ::g_kubernetes::etcd::service
  }

  include ::g_kubernetes::etcd::config
  include ::g_kubernetes::etcd::firewall

  if $ensure == 'present' {
    Class['G_kubernetes::Etcd::Package']
    ->Class['G_kubernetes::Etcd::Config']
    ~>Class['G_kubernetes::Etcd::Service']
  } else {
    Class['G_kubernetes::Etcd::Service']
    ->Class['G_kubernetes::Etcd::Package']
    ->Class['G_kubernetes::Etcd::Config']
  }
}
