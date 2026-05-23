use BDD::Behave;
use BDD::Behave::Failures;

# These specs cover aggregate-failures's rollup semantics: multiple failing
# expects inside one aggregate-failures block become a single Failure row
# at the block's call line, with the inner failures rendered as bullets
# inside the rollup message.

describe 'aggregate-failures (no label)', {
  it 'rolls up all inner failures into a single Failure row', {
    my @captured = capture-failures {
      aggregate-failures {
        expect(1).to.be(2);
        expect('a').to.be('b');
        expect(3).to.be(4);
      }
    };
    expect(@captured.elems).to.be(1);
    expect(@captured[0].message).to.include('3 expectations failed');
  }

  it 'records no rollup row when all expectations pass', {
    my @captured = capture-failures {
      aggregate-failures {
        expect(1).to.be(1);
        expect('x').to.be('x');
      }
    };
    expect(@captured.elems).to.be(0);
  }

  it 'leaves the rollup row untagged when no label is given', {
    my @captured = capture-failures {
      aggregate-failures {
        expect(1).to.be(2);
      }
    };
    expect(@captured[0].aggregation-label).to.be-nil;
  }
}

describe 'aggregate-failures (labeled)', {
  it 'tags the rollup row with the label', {
    my @captured = capture-failures {
      aggregate-failures 'validating response', {
        expect(1).to.be(2);
        expect('a').to.be('b');
      }
    };
    expect(@captured.elems).to.be(1);
    expect(@captured[0].aggregation-label).to.be('validating response');
  }

  it 'continues to run all expectations after the first failure', {
    my $second-ran = False;
    my @captured = capture-failures {
      aggregate-failures 'group', {
        expect(1).to.be(2);
        $second-ran = True;
        expect(3).to.be(4);
      }
    };
    expect($second-ran).to.be-truthy;
    expect(@captured.elems).to.be(1);
    expect(@captured[0].message).to.include('2 expectations failed');
  }

  it 'leaves failures outside the block untouched', {
    my @captured = capture-failures {
      expect(0).to.be(1);
      aggregate-failures 'inner', {
        expect(2).to.be(3);
      }
      expect(4).to.be(5);
    };
    my @labels = @captured.map(*.aggregation-label).list;
    expect(@captured.elems).to.be(3);
    expect(@labels[0]).to.be-nil;
    expect(@labels[1]).to.be('inner');
    expect(@labels[2]).to.be-nil;
  }
}

describe 'aggregate-failures (exception trapping)', {
  it 'converts an exception inside the block into a rollup failure', {
    my $reached-after = False;
    my @captured = capture-failures {
      aggregate-failures 'with-die', {
        die 'boom';
        $reached-after = True;
      }
    };
    expect(@captured.elems).to.be(1);
    expect(@captured[0].message).to.include('boom');
    expect(@captured[0].aggregation-label).to.be('with-die');
    expect($reached-after).to.be-falsy;
  }

  it 'records failures that occurred before the exception', {
    my @captured = capture-failures {
      aggregate-failures 'mixed', {
        expect(1).to.be(2);
        die 'mid';
        expect(3).to.be(4);
      }
    };
    expect(@captured.elems).to.be(1);
    expect(@captured[0].message).to.include('Expected: 1');
    expect(@captured[0].message).to.include('mid');
  }

  it 'does not propagate the exception out of the block', {
    my $caught;
    capture-failures {
      try {
        aggregate-failures {
          die 'inner-failure';
        }
        CATCH {
          default { $caught = $_; }
        }
      }
    };
    expect($caught).to.be-nil;
  }
}

describe 'aggregate-failures (nesting)', {
  it 'outer-block rollup carries the outer label', {
    my @captured = capture-failures {
      aggregate-failures 'outer', {
        aggregate-failures 'inner', {
          expect(1).to.be(2);
        }
      }
    };
    expect(@captured.elems).to.be(1);
    expect(@captured[0].aggregation-label).to.be('outer');
  }

  it 'sibling blocks each produce their own rollup row', {
    my @captured = capture-failures {
      aggregate-failures 'first', {
        expect(1).to.be(2);
      }
      aggregate-failures 'second', {
        expect(3).to.be(4);
      }
    };
    my @labels = @captured.map(*.aggregation-label).list;
    expect(@captured.elems).to.be(2);
    expect(@labels).to.eq(['first', 'second']);
  }
}

describe 'aggregate-failures (output rendering)', {
  it 'records file and line metadata on the rollup', {
    my @captured = capture-failures {
      aggregate-failures 'tag', {
        expect(1).to.be(2);
      }
    };
    my $failure  = @captured[0];
    my $has-file = $failure.file.defined && $failure.file.chars > 0;
    my $has-line = $failure.line.defined && $failure.line > 0;
    expect($has-file).to.be-truthy;
    expect($has-line).to.be-truthy;
  }
}
