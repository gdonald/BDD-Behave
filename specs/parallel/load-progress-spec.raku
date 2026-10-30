use BDD::Behave;
use BDD::Behave::LoadProgress;

describe 'LoadProgress', {
  context 'given a marker line split across two chunks', {
    let(:loads, {
      my $progress = LoadProgress.new(:total(2));
      $progress.feed("{LOAD-PROGRESS-MARKER}specs/a-spec.raku\n{LOAD-PROGRESS-MARKER}specs/");
      $progress.feed("b-spec.raku\n");
      $progress;
    });

    it 'records both spec files in load order', {
      expect(loads.loaded).to.eq(['specs/a-spec.raku', 'specs/b-spec.raku']);
    }
  }

  context 'given stderr text that is not a marker', {
    let(:loads, {
      my $progress = LoadProgress.new(:total(1));
      $progress.feed("{LOAD-PROGRESS-MARKER}specs/a-spec.raku\nwarning: deprecated\npartial");
      $progress.finish;
      $progress;
    });

    it 'keeps the other lines, including an unterminated last line', {
      expect(loads.other-text).to.eq("warning: deprecated\npartial\n");
    }

    it 'leaves them out of the loaded spec files', {
      expect(loads.loaded).to.eq(['specs/a-spec.raku']);
    }
  }

  context 'given an output callable and a clock', {
    let(:printed, {
      my @pieces;
      my @ticks = 1, 1.5, 1.5, 3;

      my $progress = LoadProgress.new(
        :total(3),
        :output(-> $text, :$partial { @pieces.push: $partial ?? $text !! $text ~ "\n" }),
        :clock({ @ticks.shift }),
      );
      $progress.feed("{LOAD-PROGRESS-MARKER}specs/a-spec.raku\n{LOAD-PROGRESS-MARKER}specs/b-spec.raku\n");
      $progress.finish;

      @pieces.join;
    });

    it 'prints a numbered line for each spec file with the seconds it took to load', {
      expect(printed()).to.eq("  [1/3] specs/a-spec.raku (0.5s)\n  [2/3] specs/b-spec.raku (1.5s)\n");
    }
  }

  describe 'describing where a load stalled', {
    it 'says no spec file had started when none loaded', {
      expect(LoadProgress.new.stall-description).to.eq('before loading any spec file');
    }

    it 'names the kind of thing being loaded when none loaded', {
      expect(LoadProgress.new(:noun<module>).stall-description).to.eq('before loading any module');
    }

    it 'names the only spec file that started loading', {
      my $progress = LoadProgress.new;
      $progress.feed("{LOAD-PROGRESS-MARKER}specs/a-spec.raku\n");

      expect($progress.stall-description).to.eq('while loading specs/a-spec.raku');
    }

    it 'names the spec file that was loading and the one loaded before it', {
      my $progress = LoadProgress.new;
      $progress.feed("{LOAD-PROGRESS-MARKER}specs/a-spec.raku\n{LOAD-PROGRESS-MARKER}specs/b-spec.raku\n");

      expect($progress.stall-description).to.eq('while loading specs/b-spec.raku (loaded after specs/a-spec.raku)');
    }
  }
}

my class CapturedStderr {
  has Str $.text = '';

  method print($text) { $!text ~= $text }
  method say($text) { $!text ~= "$text\n" }
  method flush() { }
}

sub stderr-from(&write --> Str) {
  my $*ERR = CapturedStderr.new;
  write();
  $*ERR.text;
}

describe 'note-progress', {
  it 'leaves a partial line open for the rest of it', {
    expect(stderr-from({ note-progress('  [1/2] specs/a-spec.raku', :partial) })).to.eq('  [1/2] specs/a-spec.raku');
  }

  it 'ends a whole line with a newline', {
    expect(stderr-from({ note-progress(' (0.5s)') })).to.eq(" (0.5s)\n");
  }
}

describe 'elapsed-text', {
  it 'rounds the seconds to one decimal place', {
    expect(elapsed-text(2.46)).to.eq(' (2.5s)');
  }
}
