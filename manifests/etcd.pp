class g_kubernetes::etcd(
  Hash[String, Stdlib::Host] $servers,
  Stdlib::Host $cluster_addr,
  Integer $client_port = 2379,
  G_server::Side $client_side = 'internal',
  Integer $peer_port = 2380,
  G_server::Side $peer_side = 'internal',
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
  Boolean $manage_firewall = true,

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

  # dont use system packages,
  # create user etcd and download given version from vendor

  $ssl_dir = "${config_dir}/ssl"
  $config_file = "${config_dir}/etc.yaml"

  if $package_manage {
    include ::g_kubernetes::etcd::package
  }

  if $service_manage {
    include ::g_kubernetes::etcd::service
  }

  include ::g_kubernetes::etcd::config

  if $manage_firewall {
    ['peer', 'client'].each | $type | {
      $side = getvar("::g_kubernetes::etcd::${type}_side")
      $port = getvar("::g_kubernetes::etcd::${type}_port")

      g_server::get_interfaces($side).each | $iface | {
        g_firewall { "006 Allow inbound ETCD ${type} from ${iface}":
          dport   => $port,
          proto   => tcp,
          action  => accept,
          iniface => $iface
        }
      }
    }
  }

  if $ensure == 'present' {
    Class['G_kubernetes::Etcd::Package']
    ->Class['G_kubernetes::Etcd::Config']
    ~>Class['G_kubernetes::Etcd::Service']
  } else {
    Class['G_kubernetes::Etcd::Service']
    ->Class['G_kubernetes::Etcd::Config']
    ->Class['G_kubernetes::Etcd::Package']
  }
}
