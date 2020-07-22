type G_kubernetes::CertSource = Variant[
  Stdlib::Absolutepath,
  Stdlib::Filesource,
  Pattern[
    /^-----BEGIN.*/,
  ]
]
