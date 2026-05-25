use BDD::Behave;

my $root = $?FILE.IO.parent.parent.parent;
my $bin  = $root.add('bin/behave');
my $meta = $root.add('META6.json');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);

  %( :exit($proc.exitcode), :$out, :$err );
}

sub meta-version() {
  my $content = $meta.slurp;

  $content ~~ / '"version"' \s* ':' \s* '"' (<-["]>+) '"' /;

  ~$0;
}

describe 'bin/behave --version', {
  context '--version', {
    my %r;

    before-each {
      %r = run-behave('--version');
    }

    it 'exits 0', {
      expect(%r<exit>).to.be(0);
    }

    it 'prints the version from META6.json', {
      expect(%r<out>.chomp).to.eq(meta-version());
    }

    it 'writes nothing to stderr', {
      expect(%r<err>).to.eq('');
    }
  }

  context '-V', {
    my %r;

    before-each {
      %r = run-behave('-V');
    }

    it 'exits 0', {
      expect(%r<exit>).to.be(0);
    }

    it 'prints the version from META6.json', {
      expect(%r<out>.chomp).to.eq(meta-version());
    }
  }

  it 'is mentioned in --help output', {
    my %r = run-behave('--help');

    expect(%r<out>).to.include('--version');
  }
}
