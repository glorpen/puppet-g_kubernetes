define g_kubernetes::etcd::node::peer (
  Array[Stdlib::IP::Address::Nosubnet] $ips,
  Enum['http','https'] $scheme,
  Integer $port,
  # client info for use by other modules
  Array[Stdlib::IP::Address::Nosubnet] $client_ips,
  Enum['http','https'] $client_scheme,
  Integer $client_port,
) {}
