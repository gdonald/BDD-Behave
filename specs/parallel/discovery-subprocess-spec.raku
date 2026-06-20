use BDD::Behave;
use BDD::Behave::Parallel;
use BDD::Behave::Parallel::Distribution;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

my $root    = $?FILE.IO.parent.parent.parent;
my $fixture = $root.add('t/fixtures/parallel/discovery-fixture-spec.raku');
my $clean   = $root.add('t/fixtures/parallel-clean-fixture-spec.raku');
my $bad     = $root.add('t/fixtures/parallel-bad-spec.raku');
my $worker  = $root.add('t/fixtures/parallel/worker-env-fixture-spec.raku');

sub collect-examples($node, @out) {
  given $node {
    when Example      { @out.push: $node }
    when ExampleGroup { collect-examples($_, @out) for $node.children }
    when Suite        { collect-examples($_, @out) for $node.children }
  }
}

sub example-summary($ex) {
  %(
    description       => $ex.description,
    file              => $ex.file.absolute,
    line              => $ex.line,
    pending           => $ex.pending.so,
    effective-focused => $ex.effective-focused.so,
    effective-skipped => $ex.effective-skipped.so,
    effective-tags    => $ex.effective-tags.sort.List,
  );
}

sub group-summary($g) {
  %(
    description    => $g.description,
    file           => $g.file.absolute,
    line           => $g.line,
    own-tags       => $g.tags.sort.List,
    effective-tags => $g.effective-tags.sort.List,
    metadata-type  => ($g.effective-metadata-value('type') // Str),
  );
}

sub summarize-suite($s) {
  my @groups;
  my @examples;
  sub walk($node) {
    given $node {
      when ExampleGroup {
        @groups.push: group-summary($node);
        walk($_) for $node.children;
      }
      when Example {
        @examples.push: example-summary($node);
      }
      when Suite {
        walk($_) for $node.children;
      }
    }
  }
  walk($s);
  %(
    description => $s.description,
    file        => $s.file.absolute,
    line        => $s.line,
    groups      => @groups,
    examples    => @examples,
  );
}

# Discovery loads spec files into a global registry. Running both the
# in-process and subprocess paths multiple times against the same files would
# duplicate registrations, so compute both trees once per spec run and reuse
# them across examples.
my @in-suites;
my @in-errs;
my @sub-suites;
my @sub-errs;

BEGIN {
  # nothing; we'll compute in before-all instead so registry side-effects
  # happen after the runner has populated its own state from this file
}

describe 'discover-suites-subprocess', :order<defined>, {
  before-all {
    my @files = ($fixture, $clean);
    BDD::Behave::SpecRegistry::registry().clear;
    my $in  = discover-suites(@files);
    my $sub = discover-suites-subprocess(@files);
    @in-suites  = $in[0].list;
    @in-errs    = $in[1].list;
    @sub-suites = $sub[0].list;
    @sub-errs   = $sub[1].list;
  }

  context 'parity with discover-suites', {
    it 'returns the same number of suites and load errors', {
      expect(@sub-suites.elems).to.be(@in-suites.elems);
      expect(@sub-errs.elems).to.be(@in-errs.elems);
    }

    it 'rebuilt suites match the in-process suites structurally', {
      my @in-sum  = @in-suites.map(&summarize-suite);
      my @sub-sum = @sub-suites.map(&summarize-suite);
      expect(@sub-sum.elems).to.be(@in-sum.elems);
      for ^@in-sum.elems -> $i {
        expect(@sub-sum[$i]).to.be(@in-sum[$i]);
      }
    }

    it 'rebuilt examples preserve pending/focused/skipped/effective-tags', {
      my $discovery-suite = @sub-suites.first({ .file.absolute eq $fixture.absolute });
      my @examples;
      collect-examples($discovery-suite, @examples);

      my $pending = @examples.first({ .description eq 'persists across reloads' });
      expect($pending.defined).to.be(True);
      expect($pending.pending).to.be(True);

      my $focused = @examples.first({ .description eq 'is the focused one' });
      expect($focused.defined).to.be(True);
      expect($focused.effective-focused).to.be(True);

      my $skipped = @examples.first({ .description eq 'is intentionally skipped' });
      expect($skipped.defined).to.be(True);
      expect($skipped.effective-skipped).to.be(True);

      my $tagged = @examples.first({ .description eq 'decrements the count' });
      expect($tagged.effective-tags.sort.List).to.eq(<slow unit>.sort.List);
    }

    it 'rebuilt example carries custom metadata from its ancestor group', {
      my $discovery-suite = @sub-suites.first({ .file.absolute eq $fixture.absolute });
      my @examples;
      collect-examples($discovery-suite, @examples);
      my $ex = @examples.first({ .description eq 'increments the count' });
      expect($ex.defined).to.be(True);
      expect($ex.effective-metadata-value('type')).to.be('integration');
    }

    it 'top-level example outside any describe is preserved', {
      my $discovery-suite = @sub-suites.first({ .file.absolute eq $fixture.absolute });
      my @top-level-examples = $discovery-suite.children.grep(Example);
      expect(@top-level-examples.elems).to.be(1);
      expect(@top-level-examples[0].description)
        .to.be('top-level example outside any describe');
      expect(@top-level-examples[0].effective-tags.sort.List).to.eq(<smoke>.sort.List);
    }

    it 'produces identical buckets when fed to collect-buckets', {
      my @in-bucket-ids;
      for @in-suites -> $s {
        @in-bucket-ids.append: collect-buckets($s).map(*.id);
      }

      my @sub-bucket-ids;
      for @sub-suites -> $s {
        @sub-bucket-ids.append: collect-buckets($s).map(*.id);
      }

      expect(@sub-bucket-ids.sort.List).to.eq(@in-bucket-ids.sort.List);
    }
  }

  context 'edge cases', {
    it 'returns empty results for an empty file list', {
      my $r = discover-suites-subprocess(());
      expect($r[0].elems).to.be(0);
      expect($r[1].elems).to.be(0);
    }

    it 'reports a load error when a spec file fails to load', {
      my $r = discover-suites-subprocess(($bad,));
      expect($r[1].elems > 0).to.be(True);
    }
  }

  context 'worker environment during discovery', :order<defined>, {
    let(:descriptions, {
        my %base = %*ENV.Hash;
        %base<BEHAVE_WORKER_INDEX>:delete;
        %base<BEHAVE_WORKER_COUNT>:delete;

        my $r = discover-suites-subprocess(($worker,), :base-env(%base));
        my @examples;
        collect-examples($r[0].first, @examples);
        @examples.map(*.description).List;
    });

    it 'exports BEHAVE_WORKER_COUNT when the parent env lacks it', {
      expect(descriptions.first(*.starts-with('count='))).to.eq('count=1');
    }

    it 'exports BEHAVE_WORKER_INDEX when the parent env lacks it', {
      expect(descriptions.first(*.starts-with('index='))).to.eq('index=0');
    }
  }
}
