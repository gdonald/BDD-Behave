use BDD::Behave;
use BDD::Behave::Parallel;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub built-suite(--> Suite) {
  my $file = '/abs/spec.raku'.IO;
  my $suite = Suite.new(:description('spec.raku'), :$file, :line(1));

  my $group = ExampleGroup.new(:description('math'), :$file, :line(5));
  $suite.add-child($group);

  my $fast = Example.new(:description('adds numbers'), :$file, :line(7), :block(sub { }));
  $fast.set-metadata(:tags(['fast']));
  $group.add-child($fast);

  my $slow = Example.new(:description('multiplies numbers'), :$file, :line(11), :block(sub { }));
  $slow.set-metadata(:tags(['slow']));
  $group.add-child($slow);

  $suite;
}

sub buckets(*%filters --> List) {
  collect-filtered-buckets([built-suite()], |%filters);
}

sub example-count(@buckets --> Int) {
  [+] @buckets.map(*.examples.elems);
}

describe 'collecting the buckets a parallel run will distribute', {
  context 'given no filter at all', {
    it 'keeps every example', {
      expect(example-count(buckets())).to.be(2);
    }
  }

  context 'given a tag every example carries', {
    it 'keeps the bucket whole', {
      expect(example-count(buckets(:include-tags(['fast', 'slow'])))).to.be(2);
    }
  }

  context 'given a tag one example carries', {
    it 'keeps only that example', {
      expect(example-count(buckets(:include-tags(['fast'])))).to.be(1);
    }

    it 'keeps the bucket it came from', {
      expect(buckets(:include-tags(['fast'])).elems).to.be(1);
    }
  }

  context 'given a tag no example carries', {
    it 'keeps no bucket at all', {
      expect(buckets(:include-tags(['nonexistent'])).elems).to.be(0);
    }
  }

  context 'given a tag to exclude', {
    it 'drops the example carrying it', {
      expect(example-count(buckets(:exclude-tags(['slow'])))).to.be(1);
    }
  }

  context 'given a description pattern', {
    it 'keeps the example it names', {
      expect(example-count(buckets(:example-patterns(['adds'])))).to.be(1);
    }

    it 'keeps an example named by a regex', {
      expect(example-count(buckets(:example-patterns(['/adds | divides/'])))).to.be(1);
    }

    it 'keeps nothing when the pattern names no example', {
      expect(buckets(:example-patterns(['divides'])).elems).to.be(0);
    }
  }

  context 'given a location', {
    it 'keeps the example declared there', {
      expect(example-count(buckets(:only-locations(['/abs/spec.raku:7'])))).to.be(1);
    }

    it 'keeps every example of a group declared there', {
      expect(example-count(buckets(:only-locations(['/abs/spec.raku:5'])))).to.be(2);
    }

    it 'keeps the example named by the file basename', {
      expect(example-count(buckets(:only-locations(['spec.raku:7'])))).to.be(1);
    }

    it 'keeps nothing for a line nothing was declared at', {
      expect(buckets(:only-locations(['/abs/spec.raku:99'])).elems).to.be(0);
    }

    it 'keeps nothing for a location with no line', {
      expect(buckets(:only-locations(['/abs/spec.raku'])).elems).to.be(0);
    }
  }
}

describe 'the locations a set of buckets covers', {
  it 'lists one location per example', {
    expect(locations-for-buckets(buckets()).elems).to.be(2);
  }

  it 'lists nothing for no buckets', {
    expect(locations-for-buckets([]).elems).to.be(0);
  }
}

describe 'discovering spec files that fail to load', {
  let(:broken, {
    my $path = $*TMPDIR.add("behave-broken-{$*PID}-{(now * 1e6).Int.base(36)}-spec.raku");
    $path.spurt('use BDD::Behave; this is not raku;');
    $path;
  });

  after-each {
    my $path = broken();
    $path.unlink if $path.e;
  }

  it 'reports the file that failed', {
    my ($suites, $errors) = discover-suites([broken().absolute]);

    expect($errors.elems).to.be(1);
  }

  it 'reports why it failed', {
    my ($suites, $errors) = discover-suites([broken().absolute]);

    expect($errors[0]<message>.chars > 0).to.be-truthy;
  }
}
