use BDD::Behave;
use BDD::Behave::Failures;

my class Ledger {
  method deposit($amount) { $amount }
}

# Every message below is built only when the expectation misses, so each one is
# driven through a failing expectation and read back off the failure list.
sub message-of(&expectation --> Str) {
  Failures.list = ();
  expectation();
  my $message = Failures.list.elems ?? Failures.list[0].message !! '';
  Failures.list = ();

  $message;
}

sub failure-count-of(&expectation --> Int) {
  Failures.list = ();
  expectation();
  my $count = Failures.list.elems;
  Failures.list = ();

  $count;
}

describe 'the message a missed have-received records', {
  context 'given a double that was never called', {
    let(:message, {
      message-of({
        my $log = double('Logger');
        expect($log).to.have-received('info');
      });
    });

    it 'names the double and the method', {
      expect(message()).to.include('double("Logger")#info');
    }

    it 'says the call was expected at least once', {
      expect(message()).to.include('to have been called at least once');
    }

    it 'reports that no call was seen', {
      expect(message()).to.include('got 0 calls');
    }
  }

  context 'given a real object that was called once', {
    it 'names the class and the method', {
      expect(message-of({
        my $ledger = Ledger.new;
        allow($ledger).to.receive('deposit').and-return(1);
        $ledger.deposit(1);
        expect($ledger).to.have-received('deposit').twice;
      })).to.include('Ledger#deposit');
    }

    it 'reports the one call it saw in the singular', {
      expect(message-of({
        my $ledger = Ledger.new;
        allow($ledger).to.receive('deposit').and-return(1);
        $ledger.deposit(1);
        expect($ledger).to.have-received('deposit').twice;
      })).to.include('got 1 call');
    }
  }

  context 'given a method with no stub installed at all', {
    let(:message, {
      message-of({
        my $ledger = Ledger.new;
        expect($ledger).to.have-received('deposit');
      });
    });

    it 'says no stub is installed', {
      expect(message()).to.include('no stub installed');
    }

    it 'points at the call that would install one', {
      expect(message()).to.include(".to.receive('deposit')");
    }
  }

  context 'given a call that was expected not to happen', {
    it 'says the call was expected not to have been made', {
      expect(message-of({
        my $log = double('Logger');
        $log.info('starting');
        expect($log).not.to.have-received('info');
      })).to.include('not to have been called');
    }
  }
}

describe 'the count a missed have-received reports', {
  sub missed-count-message(Str $method, &apply --> Str) {
    message-of({
      my $log = double('Logger');
      apply(expect($log).to.have-received($method));
    });
  }

  it 'reads once for exactly one call', {
    expect(missed-count-message('info', -> $e { $e.once })).to.include('exactly once');
  }

  it 'reads twice for exactly two calls', {
    expect(missed-count-message('info', -> $e { $e.twice })).to.include('exactly twice');
  }

  it 'counts in numerals from three calls up', {
    expect(missed-count-message('info', -> $e { $e.thrice })).to.include('exactly 3 times');
  }

  it 'reads once for a lower bound of one call', {
    expect(missed-count-message('info', -> $e { $e.at-least(1) })).to.include('at least once');
  }

  it 'counts in numerals for a larger lower bound', {
    expect(missed-count-message('info', -> $e { $e.at-least(4) })).to.include('at least 4 times');
  }

  it 'reads once for an upper bound of one call', {
    expect(message-of({
      my $log = double('Logger');
      $log.info('a');
      $log.info('b');
      expect($log).to.have-received('info').at-most(1);
    })).to.include('at most once');
  }

  it 'counts in numerals for a larger upper bound', {
    expect(message-of({
      my $log = double('Logger');
      $log.info($_) for ^3;
      expect($log).to.have-received('info').at-most(2);
    })).to.include('at most 2 times');
  }

  it 'names the exact count the caller asked for', {
    expect(missed-count-message('info', -> $e { $e.exactly(5) })).to.include('exactly 5 times');
  }
}

describe 'the arguments a missed have-received reports', {
  it 'renders a plain argument as it was written', {
    expect(message-of({
      my $log = double('Logger');
      $log.info('other');
      expect($log).to.have-received('info').with('expected');
    })).to.include('with ("expected")');
  }

  it 'renders an argument matcher by its description', {
    expect(message-of({
      my $log = double('Logger');
      expect($log).to.have-received('info').with(anything);
    })).to.include('with (anything)');
  }

  it 'renders a named argument with its name', {
    expect(message-of({
      my $log = double('Logger');
      expect($log).to.have-received('info').with(:level('warn'));
    })).to.include(':level("warn")');
  }

  it 'renders a named argument matcher by its description', {
    expect(message-of({
      my $log = double('Logger');
      expect($log).to.have-received('info').with(:level(anything));
    })).to.include(':level(anything)');
  }

  it 'counts the calls that matched the filter', {
    expect(message-of({
      my $log = double('Logger');
      $log.info('other');
      expect($log).to.have-received('info').with('expected');
    })).to.include('got 0 matching calls (out of 1 total)');
  }

  it 'counts a single matching call in the singular', {
    expect(message-of({
      my $log = double('Logger');
      $log.info('expected');
      $log.info('other');
      expect($log).to.have-received('info').with('expected').twice;
    })).to.include('got 1 matching call (out of 2 total)');
  }
}

describe 'a have-received chain that ends up satisfied', {
  it 'records no failure once a later link passes', {
    expect(failure-count-of({
      my $log = double('Logger');
      $log.info('starting');
      expect($log).to.have-received('info').twice.at-least(1);
    })).to.be(0);
  }

  it 'records one failure when the last link misses', {
    expect(failure-count-of({
      my $log = double('Logger');
      $log.info('starting');
      expect($log).to.have-received('info').at-least(1).twice;
    })).to.be(1);
  }
}
