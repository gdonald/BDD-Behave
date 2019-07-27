
class Failure {
  has $.desc;
  has $.line;

  submethod BUILD(:$desc, :$line) {

  }
}
