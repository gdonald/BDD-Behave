use BDD::Behave;
use BDD::Behave::Failures;

describe 'include matcher on arrays', {
  it 'matches when array contains a single item', {
    expect([1, 2, 3]).to.include(2);
  }

  it 'matches when array contains all of multiple items', {
    expect([1, 2, 3]).to.include(1, 3);
  }

  it 'matches with strings', {
    expect(['a', 'b', 'c']).to.include('a', 'c');
  }

  it 'matches nested structures via eqv', {
    expect([[1, 2], [3, 4]]).to.include([1, 2]);
  }

  it 'matches against List, not just Array', {
    expect((1, 2, 3)).to.include(2);
  }

  it 'matches against Range', {
    expect(1..5).to.include(3);
  }

  it 'fails when an item is missing (multi-item)', {
    Failures.list = ();
    expect([1, 2, 3]).to.include(2, 99);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'records a matcher-supplied failure message', {
    Failures.list = ();
    expect([1, 2, 3]).to.include(99);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected $[1, 2, 3] to include 99');
  }

  it 'negation passes when item is absent', {
    expect([1, 2, 3]).to.not.include(99);
  }

  it 'negation fails when item is present', {
    Failures.list = ();
    expect([1, 2, 3]).to.not.include(2);
    my $count = Failures.list.elems;
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($count).to.be(1);
    expect($message).to.be('expected $[1, 2, 3] not to include 2');
    expect($negated ?? 1 !! 0).to.be(1);
  }
}

describe 'include matcher on hashes', {
  it 'matches when key exists (string arg)', {
    expect({ a => 1, b => 2 }).to.include('a');
  }

  it 'matches when multiple keys exist', {
    expect({ a => 1, b => 2, c => 3 }).to.include('a', 'c');
  }

  it 'matches when key=>value pair is present', {
    expect({ a => 1, b => 2 }).to.include(a => 1);
  }

  it 'matches when multiple pairs are present', {
    expect({ a => 1, b => 2, c => 3 }).to.include(a => 1, c => 3);
  }

  it 'fails when key is missing', {
    Failures.list = ();
    expect({ a => 1 }).to.include('b');
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when key exists but value differs', {
    Failures.list = ();
    expect({ a => 1 }).to.include(a => 2);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'negation passes when key is absent', {
    expect({ a => 1 }).to.not.include('b');
  }
}

describe 'include matcher on strings', {
  it 'matches a single substring', {
    expect('hello world').to.include('world');
  }

  it 'matches multiple substrings', {
    expect('hello world').to.include('hello', 'world');
  }

  it 'fails when substring is absent', {
    Failures.list = ();
    expect('hello world').to.include('xyz');
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'negation passes when substring is absent', {
    expect('hello world').to.not.include('xyz');
  }
}

describe 'include matcher on Set/Bag', {
  it 'matches when Set contains element', {
    expect(set('a', 'b', 'c')).to.include('a');
  }

  it 'matches multiple Set elements', {
    expect(set('a', 'b', 'c')).to.include('a', 'c');
  }

  it 'fails when Set element is missing', {
    Failures.list = ();
    expect(set('a', 'b')).to.include('z');
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'matches when Bag contains element', {
    expect(bag('a', 'a', 'b')).to.include('a');
  }
}

describe 'include matcher edge cases', {
  it 'fails on undefined actual', {
    Failures.list = ();
    expect(Any).to.include(1);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'requires at least one item', {
    my $error;
    try {
      expect([1, 2, 3]).to.include();
      CATCH { default { $error = .message } }
    }
    expect($error).to.be('include requires at least one item');
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    Failures.list = ();
    expect([1, 2, 3]).to.include(99, 100);
    expect(Failures.list[0].given).to.be([1, 2, 3]);
    expect(Failures.list[0].expected).to.be([99, 100]);
    Failures.list = ();
  }
}
