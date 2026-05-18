use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/cli-line-snap-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args,
                 :out, :err, :env(|%*ENV, BEHAVE_DISABLE_CONFIG => '1'));
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s) { $s.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

sub run-docs(*@args) {
  my %r = run-behave('--format', 'documentation', |@args);
  my $clean = strip-ansi(%r<out>);
  %( |%r, :clean($clean) );
}

# Fixture line layout (cli-line-snap-spec.raku):
#  3: describe 'outer group'
#  4: it 'alpha example'
#  5-6: alpha body
#  9: it 'beta example'
# 10: beta body
# 13: context 'inner group'
# 14: it 'gamma example'
# 15-16: gamma body
# 19: it 'delta example'
# 20: delta body
# 24: it 'epsilon example'
# 25: epsilon body

describe 'bin/behave FILE:LINE line snapping', {
  describe 'exact-line matches', {
    it 'matches an `it` line directly', {
      my %r = run-docs("{$fixture.absolute}:4");
      expect(%r<exit>).to.be(0);
      expect(%r<clean>).to.include('alpha example');
      expect(%r<clean>.contains('beta example')).to.be-falsy;
    }

    it 'matches a `describe` line and runs every example beneath it', {
      my %r = run-docs("{$fixture.absolute}:3");
      expect(%r<exit>).to.be(0);
      for <alpha beta gamma delta epsilon> -> $name {
        expect(%r<clean>).to.include("$name example");
      }
    }

    it 'matches a `context` line and runs only that group\'s examples', {
      my %r = run-docs("{$fixture.absolute}:13");
      expect(%r<exit>).to.be(0);
      expect(%r<clean>).to.include('gamma example');
      expect(%r<clean>).to.include('delta example');
      for <alpha beta epsilon> -> $name {
        expect(%r<clean>.contains("$name example")).to.be-falsy;
      }
    }
  }

  describe 'snap-to-nearest-preceding', {
    it 'snaps a line inside an `it` body to the `it` line', {
      my %r = run-docs("{$fixture.absolute}:6");
      expect(%r<exit>).to.be(0);
      expect(%r<clean>).to.include('alpha example');
      expect(%r<clean>.contains('beta example')).to.be-falsy;
    }

    it 'snaps a blank line between examples to the previous example', {
      my %r = run-docs("{$fixture.absolute}:11");
      expect(%r<exit>).to.be(0);
      expect(%r<clean>).to.include('beta example');
      expect(%r<clean>.contains('alpha example')).to.be-falsy;
      expect(%r<clean>.contains('gamma example')).to.be-falsy;
    }

    it 'snaps a line inside a nested context body to the inner `it`', {
      my %r = run-docs("{$fixture.absolute}:15");
      expect(%r<exit>).to.be(0);
      expect(%r<clean>).to.include('gamma example');
      expect(%r<clean>.contains('delta example')).to.be-falsy;
    }

    it 'snaps a line after the outer closing brace to the last example', {
      my %r = run-docs("{$fixture.absolute}:27");
      expect(%r<exit>).to.be(0);
      expect(%r<clean>).to.include('epsilon example');
      for <alpha beta gamma delta> -> $name {
        expect(%r<clean>.contains("$name example")).to.be-falsy;
      }
    }
  }

  describe 'snap applies to explicit --only-example too', {
    it 'snaps the value passed to --only-example', {
      my %r = run-docs($fixture.absolute, '--only-example', "{$fixture.absolute}:6");
      expect(%r<exit>).to.be(0);
      expect(%r<clean>).to.include('alpha example');
      expect(%r<clean>.contains('beta example')).to.be-falsy;
    }

    it 'snaps the value passed to --only-example=PATH:LINE', {
      my %r = run-docs($fixture.absolute, "--only-example={$fixture.absolute}:15");
      expect(%r<exit>).to.be(0);
      expect(%r<clean>).to.include('gamma example');
      expect(%r<clean>.contains('delta example')).to.be-falsy;
    }
  }

  describe 'no snap when there is nothing to snap to', {
    it 'leaves a line above any keyword unchanged (no match)', {
      # Line 1 is `use BDD::Behave;` — no preceding keyword line.
      my %r = run-docs("{$fixture.absolute}:1");
      expect(%r<exit>).to.be(0);
      for <alpha beta gamma delta epsilon> -> $name {
        expect(%r<clean>.contains("$name example")).to.be-falsy;
      }
    }
  }
}
