type G_kubernetes::CertSource = Variant[
  Stdlib::Path,
  Stdlib::Filesource,
  Pattern[
    /^-----BEGIN.*/,
  ]
]
