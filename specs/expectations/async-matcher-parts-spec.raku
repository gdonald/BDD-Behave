use BDD::Behave;
use BDD::Behave::Matcher::Async;

# `expect` reports these through the builder, so the descriptions and the
# messages each matcher carries are read here directly.
describe 'the way an async matcher describes itself', {
  it 'describes waiting for a promise to be kept', {
    expect(BeKeptMatcher.new.description).to.eq('be kept');
  }

  it 'describes waiting for a promise to be broken', {
    expect(BeBrokenMatcher.new.description).to.eq('be broken');
  }

  it 'describes waiting for a promise to settle', {
    expect(CompleteWithinMatcher.new(:duration(2)).description).to.eq('complete within 2s');
  }

  it 'describes waiting for values from a stream', {
    expect(EmitMatcher.new(:expected([1, 2])).description).to.eq('emit [1, 2]');
  }

  it 'describes waiting for a count of values', {
    expect(EmitAtLeastMatcher.new(:minimum(3)).description).to.eq('emit at least 3 values');
  }

  it 'describes waiting for a stream to finish', {
    expect(CompleteMatcher.new(:window(1)).description).to.eq('complete within 1s');
  }

  it 'describes retrying an inner matcher', {
    my $inner = BeKeptMatcher.new;

    expect(EventuallyMatcher.new(:inner($inner)).description).to.eq('eventually be kept');
  }
}

describe 'the way an async matcher reports a match that was not wanted', {
  it 'reports a promise that was kept', {
    expect(BeKeptMatcher.new.failure-message-negated(Promise.kept(1)))
      .to.eq('expected Promise not to be kept');
  }

  it 'reports a promise that was broken with no cause read yet', {
    expect(BeBrokenMatcher.new.failure-message-negated(Promise.new))
      .to.eq('expected Promise not to be broken');
  }

  it 'reports a promise that settled inside the window', {
    my $matcher = CompleteWithinMatcher.new(:duration(2));
    $matcher.matches(Promise.kept(1));

    expect($matcher.failure-message-negated(Promise.kept(1)))
      .to.include('expected Promise not to complete within 2s');
  }

  it 'reports a stream that emitted the values', {
    expect(EmitMatcher.new(:expected([1])).failure-message-negated(Supply.from-list(1)))
      .to.eq('expected stream not to emit [1]');
  }
}

describe 'reporting a promise that was kept when it should have broken', {
  let(:matcher, { BeBrokenMatcher.new(:timeout(1)) });

  before-each { matcher().matches(Promise.kept('a value')) }

  it 'does not match', {
    expect(matcher().matches(Promise.kept('a value'))).to.be-falsy;
  }

  it 'reports the value it was kept with', {
    expect(matcher().failure-message(Promise.kept('a value')))
      .to.include('but it was kept with "a value"');
  }
}

describe 'reporting a stream that quit', {
  # A `die` inside the map quits the supply after the first value, which is
  # what the matchers report on, and it needs no timing to arrange.
  sub quitting-supply(--> Supply) {
    Supply.from-list(1, 2).map({ $_ == 2 ?? die('stream broke') !! $_ });
  }

  it 'reports the values a stream emitted before it quit', {
    my $matcher = EmitMatcher.new(:expected([1, 2]), :window(1));
    $matcher.matches(quitting-supply());

    expect($matcher.failure-message(Nil)).to.include('but it quit');
  }

  it 'names the error the stream quit with', {
    my $matcher = EmitMatcher.new(:expected([1, 2]), :window(1));
    $matcher.matches(quitting-supply());

    expect($matcher.failure-message(Nil)).to.include('stream broke');
  }

  it 'reports a count that was never reached because the stream quit', {
    my $matcher = EmitAtLeastMatcher.new(:minimum(5), :window(1));
    $matcher.matches(quitting-supply());

    expect($matcher.failure-message(Nil)).to.include('but it quit');
  }

  it 'reports a stream that quit rather than finishing', {
    my $matcher = CompleteMatcher.new(:window(1));
    $matcher.matches(quitting-supply());

    expect($matcher.failure-message(Nil)).to.include('but it quit');
  }
}
