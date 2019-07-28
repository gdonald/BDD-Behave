
class Failure {
  has Str $.desc;
  has Str $.line;

  submethod BUILD(:$!desc, :$!line) {
  }
}
