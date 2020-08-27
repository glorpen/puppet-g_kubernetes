type G_kubernetes::Vault::Template = Struct[{
  'wait_before_render'  => Optional[Integer],
  'wait_before_command' => Optional[Integer],
  'source'              => Optional[Stdlib::Filesource],
  'content'             => Optional[String],
  'destination'         => Stdlib::Absolutepath,
  'perms'               => Optional[Stdlib::Filemode],
  'backup'              => Optional[Boolean],
  'command'             => String,
  'command_timeout'     => Optional[G_kubernetes::Duration],
  'left_delimiter'      => Optional[String],
  'right_delimiter'     => Optional[String],
}]
