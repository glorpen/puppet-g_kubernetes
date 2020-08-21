class g_kubernetes::etcd::config {

  $config_dir = $::g_kubernetes::etcd::config_dir
  $ssl_dir = $::g_kubernetes::etcd::ssl_dir
  $config_file = $::g_kubernetes::etcd::config_file
  $data_dir = $::g_kubernetes::etcd::data_dir
  $options = $::g_kubernetes::etcd::options
  $servers = $::g_kubernetes::etcd::servers
  $cluster_addr = $::g_kubernetes::etcd::cluster_addr
  $client_port = $::g_kubernetes::etcd::client_port
  $peer_port = $::g_kubernetes::etcd::peer_port
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

  if $::g_kubernetes::etcd::client_auto_tls or $::g_kubernetes::etcd::client_ca_cert {
    $_client_schema = 'https'
  } else {
    $_client_schema = 'http'
  }

  if $::g_kubernetes::etcd::peer_auto_tls or $::g_kubernetes::etcd::peer_ca_cert {
    $_peer_schema = 'https'
  } else {
    $_peer_schema = 'http'
  }

  $_listen_config = Hash({
    'client' => 'listen-client-urls',
    'peer' => 'listen-peer-urls'
  }.map | $type, $config_key | {
    $side = getvar("::g_kubernetes::etcd::${type}_side")
    $port = getvar("::g_kubernetes::etcd::${type}_port")
    $schema = getvar("::g_kubernetes::etcd::config::_${type}_schema")

    [
      $config_key,
      g_server::get_interfaces($side).map | $iface | {
        $iface_config = $::facts['networking']['interfaces'][$iface]
        $iface_config['bindings'].map | $b | {
          "${schema}://${b['address']}:${port}"
        } + $iface_config['bindings6'].filter | $b | {
          $b['address'] !~ G_kubernetes::Ipv6LinkLocal
        }.map | $b | {
          "${schema}://[${b['address']}]:${port}"
        }
      }.join(',')
    ]
  })

  @@g_kubernetes::etcd::peer { $::trusted['certname']:
    ensure    => $ensure,
    peer_urls => ["${_peer_schema}://${cluster_addr}:${peer_port}"]
  }

  if $servers == undef {
    $_servers = flatten(puppetdb_query("resources[title, parameters]{exported=true and type='G_kubernetes::Etcd::Peer' and parameters.ensure='present' }").map | $info | {
      $info['parameters']['peer_urls'].map | $url | {
        "${info['title']}=${url}"
      }
    })
  } else {
    $_servers = $servers.map |$name, $ip| { "${name}=${_peer_schema}://${ip}:${peer_port}" }
  }

  $_config = merge({
    'name' => $::fqdn,
    'data-dir' => $data_dir,
    # 'wal-dir' => $wal_dir,
    'initial-advertise-peer-urls' => "${_peer_schema}://${cluster_addr}:${peer_port}",
    'advertise-client-urls' => "${_client_schema}://${cluster_addr}:${client_port}",
    'initial-cluster' => $_servers.join(','),
    'initial-cluster-token' => 'etcd-cluster',
    'initial-cluster-state' => 'new',
    'enable-v2' => false,
    'enable-pprof' => false,
    'proxy' => 'off',
    'client-transport-security' => $_configs[0],
    'peer-transport-security' => $_configs[1]
  }, $_listen_config, $options)

  file { $config_file:
    ensure  => $ensure,
    content => to_yaml($_config),
  }

}
