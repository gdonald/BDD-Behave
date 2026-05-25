use BDD::Behave;
use BDD::Behave::Failures;

describe 'freeze-time at current moment', {
  it 'freezes `now` so two calls return the same Instant', {
    freeze-time {
      my $a = now;
      sleep 0.01;
      my $b = now;

      expect($a).to.eq($b);
    };
  }

  it 'freezes DateTime.now', {
    freeze-time {
      my $a = DateTime.now;
      sleep 0.01;
      my $b = DateTime.now;

      expect($a.posix).to.eq($b.posix);
    };
  }
}

describe 'freeze-time at an explicit moment', {
  it 'freezes at a DateTime', {
    my $when = DateTime.new(:year(2030), :month(6), :day(15), :hour(12), :timezone(0));

    freeze-time $when, {
      my $seen = DateTime.now(:timezone(0));

      expect($seen.year).to.eq(2030);
      expect($seen.month).to.eq(6);
      expect($seen.day).to.eq(15);
    };
  }

  it 'freezes at an Instant', {
    my $instant = DateTime.new('2024-06-15T12:00:00Z').Instant;

    freeze-time $instant, {
      expect(now).to.eq($instant);
    };
  }

  it 'freezes at an ISO 8601 string', {
    freeze-time '2024-06-15T12:00:00Z', {
      my $seen = DateTime.now(:timezone(0));

      expect($seen.year).to.eq(2024);
      expect($seen.month).to.eq(6);
      expect($seen.day).to.eq(15);
    };
  }

  it 'freezes Date.today to the frozen day', {
    freeze-time DateTime.new('2024-07-04T12:00:00Z'), {
      my $today = Date.today(:timezone(0));

      expect($today.year).to.eq(2024);
      expect($today.month).to.eq(7);
      expect($today.day).to.eq(4);
    };
  }
}

describe 'travel-to', {
  it 'behaves like freeze-time with an explicit moment', {
    travel-to DateTime.new('2026-03-15T12:00:00Z'), {
      my $seen = DateTime.now(:timezone(0));

      expect($seen.year).to.eq(2026);
      expect($seen.month).to.eq(3);
    };
  }
}

describe 'travel-by inside a freeze block', {
  it 'advances frozen time forward by a Duration', {
    my $start = DateTime.new('2024-01-01T00:00:00Z');

    freeze-time $start, {
      expect(DateTime.now.posix).to.eq($start.posix);

      travel-by(Duration.new(3600));

      expect(DateTime.now.posix).to.eq($start.posix + 3600);
    };
  }

  it 'advances frozen time forward by a Real (seconds)', {
    my $start = DateTime.new('2024-01-01T00:00:00Z');

    freeze-time $start, {
      travel-by(60);

      expect(DateTime.now.posix).to.eq($start.posix + 60);
    };
  }

  it 'allows multiple sequential advances', {
    my $start = DateTime.new('2024-01-01T00:00:00Z');

    freeze-time $start, {
      travel-by(10);
      travel-by(20);
      travel-by(30);

      expect(DateTime.now.posix).to.eq($start.posix + 60);
    };
  }

  it 'dies when called outside a freeze block', {
    my $threw = False;
    try {
      travel-by(10);
      CATCH {
        default {
          $threw = True if .message.contains('travel-by must be called inside');
        }
      }
    }

    expect($threw).to.be-truthy;
  }
}

describe 'time restoration after a freeze block', {
  it 'returns to real time after the block exits', {
    my $frozen = DateTime.new('2020-06-15T12:00:00Z');

    freeze-time $frozen, {
      expect(DateTime.now(:timezone(0)).year).to.eq(2020);
    };

    expect(DateTime.now.year).to.be-greater-than-or-equal-to(2024);
  }

  it 'restores time even when the block throws', {
    my $frozen = DateTime.new('2020-06-15T12:00:00Z');
    my $threw = False;

    try {
      freeze-time $frozen, {
        die 'boom';
      };
      CATCH {
        default { $threw = True; }
      }
    }

    expect($threw).to.be-truthy;
    expect(DateTime.now.year).to.be-greater-than-or-equal-to(2024);
  }
}

describe 'nested freeze-time blocks', {
  it 'inner freeze shadows outer freeze', {
    my $outer = DateTime.new('2020-06-15T12:00:00Z');
    my $inner = DateTime.new('2030-06-15T12:00:00Z');

    freeze-time $outer, {
      expect(DateTime.now(:timezone(0)).year).to.eq(2020);

      freeze-time $inner, {
        expect(DateTime.now(:timezone(0)).year).to.eq(2030);
      };

      expect(DateTime.now(:timezone(0)).year).to.eq(2020);
    };
  }
}

describe 'current-time helper', {
  it 'returns frozen instant when frozen', {
    my $i = DateTime.new('2024-01-01T00:00:00Z').Instant;

    freeze-time $i, {
      expect(current-time()).to.eq($i);
    };
  }

  it 'returns real now when not frozen', {
    expect(current-time() ~~ Instant).to.be-truthy;
  }
}
