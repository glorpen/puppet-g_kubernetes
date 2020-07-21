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

  Boolean $package_manage = true,
  String $package_name = 'etcd',
  Optional[String] $package_version = 'present',

  Optional[G_kubernetes::CertSource] $client_ca_cert = undef,
  Optional[G_kubernetes::CertSource] $client_cert = undef,
  Optional[G_kubernetes::CertSource] $client_key = undef,
  Boolean $client_cert_auth = true,
  Boolean $client_auto_tls = false,

  Optional[G_kubernetes::CertSource] $peer_ca_cert = undef,
  Optional[G_kubernetes::CertSource] $peer_cert = undef,
  Optional[G_kubernetes::CertSource] $peer_key = undef,
  Boolean $peer_cert_auth = true,
  Boolean $peer_auto_tls = false
) {
  include ::g_server

  $ssl_dir = "${config_dir}/ssl"
  $config_file = "${config_dir}/etc.yaml"
  $ensure_directory = $ensure?{
    'present' => 'directory',
    default => 'absent'
  }
  $ensure_package = $ensure?{
    'present' => $package_version,
    default => 'absent'
  }

  package { $package_name:
    ensure => $ensure_package
  }
  file { $config_dir:
    ensure => $ensure_directory
  }
  file { $ssl_dir:
    ensure => $ensure_directory
  }

  $_configs = ['peer', 'client'].map | $type | {
    $ca_cert = getvar("::g_kubernetes::etcd::${type}_ca_cert")
    $ca_cert_path = g_kubernetes::certpath($ssl_dir, "${type}-ca-cert", $ca_cert)
    if $ca_cert_path {
      g_kubernetes::certsource{ $ca_cert_path:
        source => $ca_cert,
        before => File[$config_file]
      }
      $_config_ca = {
        'trusted-ca-file' => $ca_cert_path
      }
    } else {
      $_config_ca = {}
    }

    $cert = getvar("::g_kubernetes::etcd::${type}_cert")
    $cert_path = g_kubernetes::certpath($ssl_dir, "${type}-cert", $cert)
    $key = getvar("::g_kubernetes::etcd::${type}_cert")
    $key_path = g_kubernetes::certpath($ssl_dir, "${type}-key", $key)
    if $cert_path and $key_path {
      g_kubernetes::certsource{ $cert_path:
        source => $cert,
        before => File[$config_file]
      }
      g_kubernetes::certsource{ $key_path:
        source => $key,
        before => File[$config_file]
      }
      $_config_cert = {
        'key-file' => $key_path,
        'cert-file' => $cert_path,
      }
    } else {
      $_config_cert = {}
    }

    if defined(Class['g_server::firewall']) {
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

    merge(
      {
        'client-cert-auth' => getvar("::g_kubernetes::etcd::${type}_cert_auth"),
        'auto-tls' => getvar("::g_kubernetes::etcd::${type}_auto_tls")
      },
      $_config_ca,
      $_config_cert
    )
  }

  $_config = merge({
    'name' => $::fqdn,
    'data-dir' => $data_dir,
    # 'wal-dir' => $wal_dir,
    'listen-peer-urls' => "https://${cluster_addr}:${peer_port}",
    'listen-client-urls' => "https://${cluster_addr}:${client_port}",
    'initial-advertise-peer-urls' => "https://${cluster_addr}:${peer_port}",
    'advertise-client-urls' => "https://${cluster_addr}:${client_port}",
    'initial-cluster' => $servers.map |$name, $ip| { "${name}=https://${ip}:${peer_port}" }.join(','),
    'initial-cluster-token' => 'etcd-cluster',
    'initial-cluster-state' => 'new',
    'enable-v2' => false,
    'enable-pprof' => false,
    'proxy' => 'off',
    'client-transport-security' => $_configs[0],
    'peer-transport-security' => $_configs[1]
  }, $options)

  file { $config_file:
    ensure   => $ensure,
    contents => to_yaml($_config),
  }
  service { 'etcd':
    ensure => $ensure?{'present' => 'running', default => false},
    enable => $ensure?{'present' => true, default => false}
  }

  if $ensure == 'present' {
    Package[$package_name]->File[$config_file]~>Service['etcd']
    Package[$package_name]->File[$config_dir]->File[$ssl_dir]->File[$config_file]
  } else {
    Package[$package_name]->Service['etcd']->File[$config_file]
    Package[$package_name]->File[$config_file]->File[$ssl_dir]->File[$config_dir]
  }
}
