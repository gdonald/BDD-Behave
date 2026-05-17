use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $passing = $root.add('specs/expectations/be-between-spec.raku');
my $mixed   = $root.add('t/fixtures/progress-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'bin/behave --format html', {
  it 'is listed in --help output', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('html');
  }

  it 'emits a complete HTML5 document for a passing run', {
    my %r = run-behave('--format', 'html', '--order', 'defined', $passing.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.match(/^^ '<!DOCTYPE html>'/);
    expect(%r<out>).to.include('<title>Behave Test Report</title>');
    expect(%r<out>).to.include('</html>');
  }

  it 'wraps groups in <details><summary> for collapsibility', {
    my %r = run-behave('--format=html', '--order', 'defined', $passing.absolute);
    expect(%r<out>).to.include('<details open class="group">');
    expect(%r<out>).to.include('<summary class="group-summary">');
  }

  it 'renders the mixed fixture with all four outcome classes', {
    my %r = run-behave('--format', 'html', '--order', 'defined', $mixed.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>).to.include('class="example pass"');
    expect(%r<out>).to.include('class="example fail"');
    expect(%r<out>).to.include('class="example pending"');
    expect(%r<out>).to.include('class="example skipped"');
    expect(%r<out>).to.include('class="failure-detail"');
    expect(%r<out>).to.include('class="summary has-failures"');
  }

  it 'suppresses default per-example output', {
    my %r = run-behave('--format', 'html', '--order', 'defined', $mixed.absolute);
    expect(%r<out>.contains('SUCCESS')).to.be-falsy;
    expect(%r<out>.contains("⮑")).to.be-falsy;
  }
}
