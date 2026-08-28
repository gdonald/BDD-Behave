use BDD::Behave;
use BDD::Behave::Watch::UI;

# The UI writes to a handle it is given, so each line it can write is read back
# from a file rather than from the terminal.
sub ui-writing-to(IO::Path $path, Bool :$color = False) {
  BDD::Behave::Watch::UI::UI.new(:$color, :out($path.open(:w)));
}

describe 'the lines watch mode writes', {
  let(:path, {
    $*TMPDIR.add("behave-watch-ui-{$*PID}-{(now * 1e6).Int.base(36)}.txt");
  });

  after-each {
    my $file = path();
    $file.unlink if $file.e;
  }

  sub written(&say-it --> Str) {
    my $ui = ui-writing-to(path());
    say-it($ui);
    $ui.out.close;

    path().slurp;
  }

  it 'writes a banner', {
    expect(written(-> $ui { $ui.banner('starting watch mode') }))
      .to.include('[behave watch] starting watch mode');
  }

  it 'writes a note', {
    expect(written(-> $ui { $ui.info('nothing to do') }))
      .to.include('[behave watch] nothing to do');
  }

  it 'writes a warning', {
    expect(written(-> $ui { $ui.warn('unknown command') }))
      .to.include('[behave watch] unknown command');
  }

  it 'writes an error', {
    expect(written(-> $ui { $ui.error('the run died') }))
      .to.include('[behave watch] the run died');
  }
}

describe 'the lines watch mode writes in color', {
  let(:path, {
    $*TMPDIR.add("behave-watch-ui-color-{$*PID}-{(now * 1e6).Int.base(36)}.txt");
  });

  after-each {
    my $file = path();
    $file.unlink if $file.e;
  }

  sub written(&say-it --> Str) {
    my $ui = ui-writing-to(path(), :color);
    say-it($ui);
    $ui.out.close;

    path().slurp;
  }

  it 'colors an error', {
    expect(written(-> $ui { $ui.error('the run died') })).to.include("\e[");
  }

  it 'still carries the text of the error', {
    expect(written(-> $ui { $ui.error('the run died') })).to.include('the run died');
  }

  it 'colors a warning', {
    expect(written(-> $ui { $ui.warn('unknown command') })).to.include("\e[");
  }

  it 'leaves a note uncolored', {
    expect(written(-> $ui { $ui.info('nothing to do') })).to.not.include("\e[");
  }
}
