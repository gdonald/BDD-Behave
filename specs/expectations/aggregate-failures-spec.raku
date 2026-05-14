use BDD::Behave;
use BDD::Behave::Failures;

describe 'aggregate-failures (no label)', {
  it 'runs the block and collects all failures', {
    Failures.list = ();
    aggregate-failures {
      expect(1).to.be(2);
      expect('a').to.be('b');
      expect(3).to.be(4);
    }
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(3);
  }

  it 'records no failures when all expectations pass', {
    Failures.list = ();
    aggregate-failures {
      expect(1).to.be(1);
      expect('x').to.be('x');
    }
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(0);
  }

  it 'does not tag failures with a label', {
    Failures.list = ();
    aggregate-failures {
      expect(1).to.be(2);
    }
    my $label = Failures.list[0].aggregation-label;
    Failures.list = ();
    expect($label).to.be-nil;
  }
}

describe 'aggregate-failures (labeled)', {
  it 'tags all failures with the label', {
    Failures.list = ();
    aggregate-failures 'validating response', {
      expect(1).to.be(2);
      expect('a').to.be('b');
    }
    my @labels = Failures.list.map(*.aggregation-label).list;
    Failures.list = ();
    expect(@labels).to.eq(['validating response', 'validating response']);
  }

  it 'continues to run all expectations after the first failure', {
    Failures.list = ();
    my $second-ran = False;
    aggregate-failures 'group', {
      expect(1).to.be(2);
      $second-ran = True;
      expect(3).to.be(4);
    }
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($second-ran).to.be-truthy;
    expect($count).to.be(2);
  }

  it 'leaves failures outside the block untouched', {
    Failures.list = ();
    expect(0).to.be(1);
    aggregate-failures 'inner', {
      expect(2).to.be(3);
    }
    expect(4).to.be(5);
    my @labels = Failures.list.map(*.aggregation-label).list;
    Failures.list = ();
    expect(@labels[0]).to.be-nil;
    expect(@labels[1]).to.be('inner');
    expect(@labels[2]).to.be-nil;
  }
}

describe 'aggregate-failures (exception trapping)', {
  it 'converts an exception inside the block into a failure', {
    Failures.list = ();
    my $reached-after = False;
    aggregate-failures 'with-die', {
      die 'boom';
      $reached-after = True;
    }
    my @failures = Failures.list.list;
    my $count = @failures.elems;
    my $first-message = @failures[0].message;
    my $first-label = @failures[0].aggregation-label;
    Failures.list = ();
    expect($count).to.be(1);
    expect($first-message).to.include('boom');
    expect($first-label).to.be('with-die');
    expect($reached-after).to.be-falsy;
  }

  it 'records failures that occurred before the exception', {
    Failures.list = ();
    aggregate-failures 'mixed', {
      expect(1).to.be(2);
      die 'mid';
      expect(3).to.be(4);
    }
    my $count = Failures.list.elems;
    my @messages = Failures.list.map(*.message).list;
    Failures.list = ();
    expect($count).to.be(2);
    expect(@messages[1]).to.include('mid');
  }

  it 'does not propagate the exception out of the block', {
    Failures.list = ();
    my $caught;
    try {
      aggregate-failures {
        die 'inner-failure';
      }
      CATCH {
        default { $caught = $_; }
      }
    }
    Failures.list = ();
    expect($caught).to.be-nil;
  }
}

describe 'aggregate-failures (nesting)', {
  it 'inner labeled block uses its own label', {
    Failures.list = ();
    aggregate-failures 'outer', {
      aggregate-failures 'inner', {
        expect(1).to.be(2);
      }
    }
    my $label = Failures.list[0].aggregation-label;
    Failures.list = ();
    expect($label).to.be('inner');
  }

  it 'inner unlabeled block inherits outer label', {
    Failures.list = ();
    aggregate-failures 'outer', {
      aggregate-failures {
        expect(1).to.be(2);
      }
    }
    my $label = Failures.list[0].aggregation-label;
    Failures.list = ();
    expect($label).to.be('outer');
  }

  it 'sibling blocks isolate their labels', {
    Failures.list = ();
    aggregate-failures 'first', {
      expect(1).to.be(2);
    }
    aggregate-failures 'second', {
      expect(3).to.be(4);
    }
    my @labels = Failures.list.map(*.aggregation-label).list;
    Failures.list = ();
    expect(@labels).to.eq(['first', 'second']);
  }
}

describe 'aggregate-failures (output rendering)', {
  it 'records file and line metadata on each tagged failure', {
    Failures.list = ();
    aggregate-failures 'tag', {
      expect(1).to.be(2);
    }
    my $failure = Failures.list[0];
    my $has-file = $failure.file.defined && $failure.file.chars > 0;
    my $has-line = $failure.line.defined && $failure.line > 0;
    Failures.list = ();
    expect($has-file).to.be-truthy;
    expect($has-line).to.be-truthy;
  }
}
