function g_kubernetes::certpath(
  Stdlib::Absolutepath $ssl_dir,
  String $name,
  Optional[G_kubernetes::CertSource] $source = undef
){
  case $source {
    undef: { undef }
    Stdlib::Absolutepath: { $source }
    default: { "${ssl_dir}/${name}.pem" }
  }
}
