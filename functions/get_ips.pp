function g_kubernetes::get_ips(
  G_server::Side $side,
){
  flatten(g_server::get_interfaces($side).map | $iface | {
    $addrs = delete_undef_values([
      G_server::Network::Iface[$iface]['ipv4addr'],
      G_server::Network::Iface[$iface]['ipv6addr']
    ])
    if $addrs.empty() {
      $_network_info = $::facts['networking']['interfaces'][$iface]
      ['', '6'].map |$t| {
        $_network_info["bindings${t}"].map | $c | {
          $c['address']
        }.filter | $i | {
          $i !~ G_kubernetes::Ipv6LinkLocal
        }
      }
    } else {
      $addrs
    }
  }).map | $ip | {
    # remove masks
    regsubst($ip, '/.*', '')
  }
}
