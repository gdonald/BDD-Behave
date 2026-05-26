class X::ImportRepro::Boom is Exception is export {
  has Str $.detail;
  method message { "boom: $!detail" }
}
