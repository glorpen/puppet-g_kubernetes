class g_kubernetes::etcd::config {

  $config_dir = $::g_kubernetes::etcd::config_dir
  $ssl_dir = $::g_kubernetes::etcd::ssl_dir
  $config_file = $::g_kubernetes::etcd::config_file
  $data_dir = $::g_kubernetes::etcd::data_dir
  $options = $::g_kubernetes::etcd::options
  $servers = $::g_kubernetes::etcd::servers
  $client_port = $::g_kubernetes::etcd::client_port
  $client_schema = $::g_kubernetes::etcd::client_schema
  $peer_port = $::g_kubernetes::etcd::peer_port
  $peer_schema = $::g_kubernetes::etcd::peer_schema
  $ensure = $::g_kubernetes::etcd::ensure

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

    merge(
      {
        'client-cert-auth' => getvar("::g_kubernetes::etcd::${type}_cert_auth"),
        'auto-tls' => getvar("::g_kubernetes::etcd::${type}_auto_tls")
      },
      $_config_ca,
      $_config_cert
    )
  }

  if $servers == undef {
    $_servers = flatten(puppetdb_query("resources[title, parameters]{
      exported=true and type='G_kubernetes::Etcd::Node::Peer'
    }").map | $info | {
      enclose_ipv6($info['parameters']['ips']).map | $ip | {
        "${info['title']}=${info['schema']}://${ip}:${info['port']}"
      }
    })
  } else {
    $_servers = $servers.map |$name, $ip| { "${name}=${peer_schema}://${ip}:${peer_port}" }
  }

  $_config = merge({
    'name' => $::fqdn,
    'data-dir' => $data_dir,
    # 'wal-dir' => $wal_dir,
    'initial-advertise-peer-urls' => enclose_ipv6($::g_kubernetes::etcd::peer_ips).map |$ip| {
      "${peer_schema}://${ip}:${peer_port}"
    }.join(','),
    'advertise-client-urls' => enclose_ipv6($::g_kubernetes::etcd::peer_ips).map |$ip| {
      "${client_schema}://${ip}:${client_port}"
    }.join(','),
    'initial-cluster' => $_servers.join(','),
    'initial-cluster-token' => 'etcd-cluster',
    'initial-cluster-state' => 'new',
    'enable-v2' => false,
    'enable-pprof' => false,
    'proxy' => 'off',
    'client-transport-security' => $_configs[0],
    'peer-transport-security' => $_configs[1],
    'listen-client-urls' => "${client_schema}://0.0.0.0:${client_port}",
    'listen-peer-urls' => "${peer_schema}://0.0.0.0:${peer_port}"
  }, $options)

  file { $config_file:
    ensure  => $ensure,
    content => to_yaml($_config),
  }
}
