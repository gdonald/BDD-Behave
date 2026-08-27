use BDD::Behave;

# `anything` and friends already come in through BDD::Behave, so the module is
# pulled in without importing, and the frame helper is called by its full name.
need BDD::Behave::Mock::ArgMatcher;

describe 'the way an argument matcher describes itself', {
  it 'describes a matcher that takes anything', {
    expect(anything.describe).to.eq('anything');
  }

  it 'describes a matcher that takes one type', {
    expect(instance-of(Int).describe).to.eq('instance-of(Int)');
  }

  it 'describes a matcher that takes a hash holding given pairs', {
    expect(hash-including(:size(3)).describe).to.eq('hash-including({:size(3)})');
  }

  it 'describes a matcher that takes a list holding given items', {
    expect(array-including(1, 2).describe).to.eq('array-including([1, 2])');
  }
}

describe 'a matcher for a list holding given items', {
  context 'given plain items', {
    it 'matches a list holding all of them', {
      expect(array-including(1, 3).matches([1, 2, 3])).to.be-truthy;
    }

    it 'does not match a list missing one of them', {
      expect(array-including(1, 9).matches([1, 2, 3])).to.be-falsy;
    }

    it 'does not match something that is not a list', {
      expect(array-including(1).matches('not a list')).to.be-falsy;
    }
  }

  context 'given an item that is itself a matcher', {
    it 'matches a list holding a value that matcher accepts', {
      expect(array-including(instance-of(Str)).matches(['a string', 2])).to.be-truthy;
    }

    it 'does not match a list holding nothing that matcher accepts', {
      expect(array-including(instance-of(Str)).matches([1, 2])).to.be-falsy;
    }
  }
}

describe 'a matcher for a hash holding given pairs', {
  it 'matches a hash holding the pair', {
    expect(hash-including(:size(3)).matches({ :size(3), :name('a') })).to.be-truthy;
  }

  it 'does not match a hash holding a different value for the key', {
    expect(hash-including(:size(3)).matches({ :size(4) })).to.be-falsy;
  }

  it 'does not match something that is not a hash', {
    expect(hash-including(:size(3)).matches('not a hash')).to.be-falsy;
  }
}

describe 'the frame a mock reports a call from', {
  it 'skips the frames inside the mocking code itself', {
    expect(BDD::Behave::Mock::ArgMatcher::user-callframe().file.contains('BDD/Behave/Mock')).to.be-falsy;
  }

  it 'reports the frame of the caller', {
    expect(BDD::Behave::Mock::ArgMatcher::user-callframe().file.ends-with('arg-matcher-spec.raku')).to.be-truthy;
  }
}
