use BDD::Behave;

# `freeze-time` and friends already come in through BDD::Behave, so the module
# is pulled in without importing and its readers are called by their full name.
need BDD::Behave::Time;

describe 'reading the instant a run is frozen at', {
  context 'given no freeze in effect', {
    it 'reports no frozen instant', {
      expect(BDD::Behave::Time::frozen-instant().defined).to.be-falsy;
    }

    it 'reports that time is not frozen', {
      expect(BDD::Behave::Time::time-is-frozen()).to.be-falsy;
    }
  }

  context 'given a freeze in effect', {
    it 'reports the instant it was frozen at', {
      my $moment = DateTime.new('2020-05-15T12:00:00Z').Instant;

      freeze-time($moment, {
        expect(BDD::Behave::Time::frozen-instant()).to.be($moment);
      });
    }

    it 'reports that time is frozen', {
      freeze-time({
        expect(BDD::Behave::Time::time-is-frozen()).to.be-truthy;
      });
    }
  }
}

describe 'turning a moment into an instant', {
  it 'takes an instant as it is', {
    my $moment = DateTime.new('2020-05-15T12:00:00Z').Instant;

    expect(BDD::Behave::Time::to-instant($moment)).to.be($moment);
  }

  it 'takes a date and time', {
    expect(BDD::Behave::Time::to-instant(DateTime.new('2020-05-15T12:00:00Z')))
      .to.be(DateTime.new('2020-05-15T12:00:00Z').Instant);
  }

  it 'takes a date', {
    expect(BDD::Behave::Time::to-instant(Date.new('2020-05-15')))
      .to.be(Date.new('2020-05-15').DateTime.Instant);
  }

  it 'takes a string', {
    expect(BDD::Behave::Time::to-instant('2020-05-15T12:00:00Z'))
      .to.be(DateTime.new('2020-05-15T12:00:00Z').Instant);
  }

  it 'takes a count of seconds since the epoch', {
    expect(BDD::Behave::Time::to-instant(1589544000).DateTime.year).to.be(2020);
  }

  it 'takes a fractional count of seconds', {
    expect(BDD::Behave::Time::to-instant(1589544000.5).DateTime.year).to.be(2020);
  }

  it 'refuses anything it cannot read as a moment', {
    expect({ BDD::Behave::Time::to-instant([1, 2, 3]) })
      .to.raise-error(/'cannot convert'/);
  }

  it 'names the type it was handed in the refusal', {
    expect({ BDD::Behave::Time::to-instant([1, 2, 3]) }).to.raise-error(/'Array'/);
  }
}

describe 'the wrapped date and time constructors', {
  let(:moment, { DateTime.new('2020-05-15T12:00:00Z') });

  it 'reports the frozen moment from DateTime.now', {
    freeze-time(moment().Instant, {
      expect(DateTime.now(:timezone(0)).year).to.be(2020);
    });
  }

  it 'reports the frozen day from Date.today', {
    freeze-time(moment().Instant, {
      expect(Date.today(:timezone(0)).Str).to.eq('2020-05-15');
    });
  }

  it 'reports the real year outside a freeze', {
    expect(DateTime.now.year >= 2024).to.be-truthy;
  }

  it 'reports a real day outside a freeze', {
    expect(Date.today.year >= 2024).to.be-truthy;
  }
}
