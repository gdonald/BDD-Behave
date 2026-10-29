use BDD::Behave;
use BDD::Behave::LoadProgress;
use BDD::Behave::SpecLoader;

my $empty-fixture = $?FILE.IO.parent.parent.parent.add('t/fixtures/parallel/empty-fixture-spec.raku');

my class CapturedStderr {
  has @.lines;

  method say($line) { @!lines.push: ~$line }
  method flush() { }
}

sub stderr-while-loading(Bool :$progress --> List) {
  my $*ERR = CapturedStderr.new;
  temp %*ENV;
  $progress ?? (%*ENV<BEHAVE_LOAD_PROGRESS> = '1') !! (%*ENV<BEHAVE_LOAD_PROGRESS>:delete);

  load-spec-file($empty-fixture);
  $*ERR.lines.List;
}

describe 'loading a spec file', {
  it 'writes a load progress line naming the file when progress is asked for', {
    expect(stderr-while-loading(:progress)).to.eq((LOAD-PROGRESS-MARKER ~ $empty-fixture,));
  }

  it 'writes nothing when progress is not asked for', {
    expect(stderr-while-loading(:!progress)).to.eq(());
  }
}
