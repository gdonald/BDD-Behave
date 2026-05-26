use BDD::Behave;

# Regression: when one spec triggers DBIish.connect at file load (which does
# a runtime `require ::($driver)` internally), a sibling spec that imports
# `X::*` symbols via `is export` from a separate module loses access to them
# inside its `it` blocks. The closure raises:
#
#   Could not find symbol '&Boom' in 'X::ImportRepro'
#
# Reproduces with:
#   raku -Ilib -It/fixtures/x-import bin/behave --order=defined \
#     t/fixtures/x-import/a-spec.raku \
#     t/fixtures/x-import/b-spec.raku
#
# See t/fixtures/x-import/ for the minimal fixtures.

sub run-behave(--> Hash) {
  my $root    = $?FILE.IO.parent.parent.parent;
  my $bin     = $root.add('bin/behave');
  my $fixture = $root.add('t/fixtures/x-import');
  my @cmd     = 'raku', '-Ilib', "-I{$fixture.absolute}", $bin.absolute,
                '--order=defined',
                $fixture.add('a-spec.raku').absolute,
                $fixture.add('b-spec.raku').absolute;
  my $proc    = run(|@cmd, :out, :err, :cwd($root.absolute));
  %(
    :exitcode($proc.exitcode),
    :stdout($proc.out.slurp(:close)),
    :stderr($proc.err.slurp(:close)),
  );
}

describe 'spec loader: X:: imports survive a sibling spec doing runtime require', {
  my %result;
  before-all { %result = run-behave }

  it 'exits 0', {
    expect(%result<exitcode>).to.eq(0);
  }

  it 'produces output (so the not.match below cannot pass vacuously)', {
    expect(%result<stdout>).not.to.eq('');
  }

  it 'b-spec sees X::ImportRepro::Boom from its own use', {
    expect(%result<stdout>).not.to.match(/"Could not find symbol '&Boom' in 'X::ImportRepro'"/);
  }

  it 'reports 2 examples passed', {
    expect(%result<stdout>).to.match(/"2 passed"/);
  }
}
