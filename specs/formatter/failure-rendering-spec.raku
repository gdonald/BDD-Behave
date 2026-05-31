use BDD::Behave;

# The fixture deliberately keeps known line numbers so the spec can assert each
# formatter surfaces them. Don't reformat without updating the EXPECTED-* constants.
#
#   line 1: use BDD::Behave;
#   line 2: (blank)
#   line 3: describe 'fmt-render-fixture', {
#   line 4:   it 'dies with a unique die-failure marker', {
#   line 5:     die 'BEHAVE_DIE_MARKER_kaboom';
#   line 6:   }
#   line 7: (blank)
#   line 8:   it 'fails with a unique expect-failure marker', {
#   line 9:     expect('BEHAVE_GIVEN_VALUE_42').to.be('BEHAVE_EXPECTED_VALUE_99');
#   line 10:  }
#   line 11: }
constant DIE-DESC      = 'dies with a unique die-failure marker';
constant DIE-IT-LINE   = 4;

constant EXPECT-DESC   = 'fails with a unique expect-failure marker';
constant EXPECT-LINE   = 9;

sub run-fixture(Str $fmt --> List) {
  # Digit-free, formatter-unique name: a timestamp/PID here would leak digits
  # into the output and spuriously satisfy the line-number contains() check.
  my $tmp = $*TMPDIR.add("behave-fmt-render-{$fmt}-spec.raku");

  $tmp.spurt(q:to/RAKU/);
    use BDD::Behave;

    describe 'fmt-render-fixture', {
      it 'dies with a unique die-failure marker', {
        die 'BEHAVE_DIE_MARKER_kaboom';
      }

      it 'fails with a unique expect-failure marker', {
        expect('BEHAVE_GIVEN_VALUE_42').to.be('BEHAVE_EXPECTED_VALUE_99');
      }
    }
    RAKU

  my @cmd = 'raku', '-Ilib', 'bin/behave', '--format', $fmt, $tmp.absolute;
  my $proc = run(|@cmd, :out, :err, :merge);
  my $out  = $proc.out.slurp(:close);

  my $basename = $tmp.basename;

  $tmp.unlink;

  ($out, $basename);
}

sub check-renders-failure(Str $fmt, Str $out, Str $basename, Str $description, Int $line, Str $kind) {
  my @missing;

  @missing.push: "fixture filename ($basename)"               unless $out.contains($basename);
  @missing.push: "example description ($description)"          unless $out.contains($description);
  @missing.push: "source line number ($line)"                  unless $out.contains($line.Str);

  return unless @missing.elems;

  die "$fmt formatter dropped these pieces of the $kind failure: { @missing.join(', ') }.\n"
    ~ "Maintainer needs file + line + description in every formatter so users can navigate to and fix the failing spec.\n"
    ~ "--- BEGIN $fmt OUTPUT ---\n"
    ~ $out
    ~ "\n--- END $fmt OUTPUT ---";
}

sub check-formatter(Str $fmt) {
  my ($out, $basename) = run-fixture($fmt);

  check-renders-failure($fmt, $out, $basename, DIE-DESC,    DIE-IT-LINE, 'die-based');
  check-renders-failure($fmt, $out, $basename, EXPECT-DESC, EXPECT-LINE, 'expectation-based');
}

describe 'every formatter shows file + line + description for a failing user spec', {
  it 'tree formatter',          { check-formatter('tree')          }
  it 'progress formatter',      { check-formatter('progress')      }
  it 'documentation formatter', { check-formatter('documentation') }
  it 'html formatter',          { check-formatter('html')          }
  it 'tap formatter',           { check-formatter('tap')           }
  it 'junit formatter',         { check-formatter('junit')         }
  it 'json formatter',          { check-formatter('json')          }
  it 'json-events formatter',   { check-formatter('json-events')   }
}
