define g_kubernetes::etcd::peer (
  Array[String] $peer_urls,
  Enum['present', 'absent'] $ensure = 'present',
) {}
