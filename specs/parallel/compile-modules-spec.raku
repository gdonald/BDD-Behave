use BDD::Behave;
use BDD::Behave::LoadProgress;
use BDD::Behave::SpecLoader;

my $fixtures = $?FILE.IO.parent.parent.parent.add('t/fixtures/parallel');

my class CapturedStderr {
  has @.lines;

  method say($line) { @!lines.push: ~$line }
  method flush() { }
}

sub compile-modules-exit-code(IO::Path $meta --> Int) {
  my $proc = run 'raku', '-Ilib', 'bin/behave', '--no-config', "--compile-modules={$meta.absolute}", :out, :err;
  $proc.out.slurp(:close);
  $proc.err.slurp(:close);

  $proc.exitcode;
}

describe 'listing the modules a META6.json provides', {
  it 'reads the module names listed under provides', {
    expect(provided-modules($fixtures.add('compile-modules/META6.json'))).to.eq(('BDD::Behave::LoadProgress',));
  }

  it 'lists no modules when the file is missing', {
    expect(provided-modules($fixtures.add('no-such-dir/META6.json'))).to.eq(());
  }
}

describe 'loading a module', {
  it 'writes a load progress line naming it when progress is asked for', {
    my $*ERR = CapturedStderr.new;
    temp %*ENV;
    %*ENV<BEHAVE_LOAD_PROGRESS> = '1';

    load-module('BDD::Behave::LoadProgress');

    expect($*ERR.lines.List).to.eq((LOAD-PROGRESS-MARKER ~ 'BDD::Behave::LoadProgress',));
  }
}

describe 'behave --compile-modules', {
  it 'exits 0 when every provided module loads', {
    expect(compile-modules-exit-code($fixtures.add('compile-modules/META6.json'))).to.be(0);
  }

  it 'exits 1 when a provided module fails to load', {
    expect(compile-modules-exit-code($fixtures.add('compile-modules-missing/META6.json'))).to.be(1);
  }
}
