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
  String $package_version = '3.4.10',
  Optional[String] $package_checksum = undef,
  Boolean $service_manage = true,
  Boolean $manage_firewall = true,

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

# ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
# ETCD_LISTEN_CLIENT_URLS="http://localhost:2379"
# ETCD_NAME="default"
# ETCD_ADVERTISE_CLIENT_URLS="http://localhost:2379"
# cat /usr/lib/systemd/system/etcd.service
# [Unit]
# Description=Etcd Server
# After=network.target
# After=network-online.target
# Wants=network-online.target

# [Service]
# Type=notify
# WorkingDirectory=/var/lib/etcd/
# EnvironmentFile=-/etc/etcd/etcd.conf
# User=etcd
# # set GOMAXPROCS to number of processors
# ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/bin/etcd --name=\"${ETCD_NAME}\" --data-dir=\"${ETCD_DATA_DIR}\" --listen-client-urls=\"${ETCD_LISTEN_CLIENT_URLS}\""
# Restart=on-failure
# LimitNOFILE=65536

# [Install]
# WantedBy=multi-user.target
}
