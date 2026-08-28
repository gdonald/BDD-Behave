use BDD::Behave;
use BDD::Behave::Watch::UI;

# The reader thread pulls lines off the handle the UI was given, so a file
# standing in for the terminal drives it here.
sub ui-reading(*@lines --> BDD::Behave::Watch::UI::UI) {
  my $path = $*TMPDIR.add("behave-watch-reader-{$*PID}-{(now * 1e6).Int.base(36)}.txt");
  $path.spurt(@lines.elems ?? @lines.join("\n") ~ "\n" !! '');

  my $ui = BDD::Behave::Watch::UI::UI.new(
    :in($path.open(:r)),
    :out(open('/dev/null', :w)),
  );
  $ui.start-reader;

  $path.unlink;
  $ui;
}

# The reader runs on its own thread, so a poll can arrive before the line does.
sub next-command(BDD::Behave::Watch::UI::UI $ui --> Str) {
  for ^200 {
    my $cmd = $ui.poll-command;
    return $cmd if $cmd.defined;
    sleep 0.01;
  }
  Str;
}

describe 'the watch mode reader thread', {
  it 'queues the first line it reads', {
    my $ui = ui-reading('r');
    LEAVE { $ui.stop }

    expect(next-command($ui)).to.eq('r');
  }

  it 'queues each line in the order it was read', {
    my $ui = ui-reading('r', 'a', 'q');
    LEAVE { $ui.stop }

    expect((next-command($ui), next-command($ui), next-command($ui))).to.eq(<r a q>);
  }

  it 'lowercases and trims what it read', {
    my $ui = ui-reading('  Q  ');
    LEAVE { $ui.stop }

    expect(next-command($ui)).to.eq('q');
  }

  it 'starts only one reader', {
    my $ui = ui-reading('r');
    LEAVE { $ui.stop }
    $ui.start-reader;

    expect(next-command($ui)).to.eq('r');
  }

  it 'reports no command when nothing was read', {
    my $ui = ui-reading();
    LEAVE { $ui.stop }

    expect($ui.poll-command.defined).to.be-falsy;
  }
}

describe 'a command submitted without the reader', {
  it 'is polled back', {
    my $ui = BDD::Behave::Watch::UI::UI.new(:out(open('/dev/null', :w)));
    LEAVE { $ui.stop }
    $ui.submit-command('a');

    expect($ui.poll-command).to.eq('a');
  }
}
