use BDD::Behave;
use BDD::Behave::DocExtractor;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub build-suite() {
  my $suite = Suite.create(
    :description('demo-spec.raku'),
    :file('/tmp/demo-spec.raku'.IO),
    :line(0),
  );

  my $calc = ExampleGroup.new(
    :description('Calculator'),
    :file('/tmp/demo-spec.raku'.IO),
    :line(3),
  );
  $suite.add-group($calc);

  my $add = ExampleGroup.new(
    :description('addition'),
    :file('/tmp/demo-spec.raku'.IO),
    :line(5),
  );
  $calc.add-group($add);

  my $ex1 = Example.new(
    :description('adds two positive numbers'),
    :file('/tmp/demo-spec.raku'.IO),
    :line(6),
    :block({ Nil }),
  );
  $ex1.set-metadata(:tags(<user-facing>));
  $ex1.set-metadata(:type<unit>);
  $add.add-example($ex1);

  my $ex2 = Example.new(
    :description('handles zero'),
    :file('/tmp/demo-spec.raku'.IO),
    :line(7),
    :block({ Nil }),
  );
  $ex2.set-metadata(:type<unit>);
  $add.add-example($ex2);

  my $ex-pending = Example.new(
    :description('handles overflow'),
    :file('/tmp/demo-spec.raku'.IO),
    :line(8),
    :block({ Nil }),
    :pending,
  );
  $add.add-example($ex-pending);

  my $sub = ExampleGroup.new(
    :description('subtraction'),
    :file('/tmp/demo-spec.raku'.IO),
    :line(10),
  );
  $calc.add-group($sub);

  my $ex3 = Example.new(
    :description('subtracts two numbers'),
    :file('/tmp/demo-spec.raku'.IO),
    :line(11),
    :block({ Nil }),
  );
  $ex3.set-metadata(:tags(<internal>));
  $sub.add-example($ex3);

  my $skipped = Example.new(
    :description('skipped one'),
    :file('/tmp/demo-spec.raku'.IO),
    :line(12),
    :block({ Nil }),
  );
  $skipped.set-metadata(:skipped(True));
  $sub.add-example($skipped);

  $suite;
}

describe 'BDD::Behave::DocExtractor', {
  describe 'construction', {
    it 'defaults to markdown format', {
      my $ex = BDD::Behave::DocExtractor::DocExtractor.new;
      expect($ex.format).to.eq('markdown');
    }

    it 'accepts markdown, html, and json formats', {
      for <markdown html json> -> $f {
        my $ex = BDD::Behave::DocExtractor::DocExtractor.new(:format($f));
        expect($ex.format).to.eq($f);
      }
    }

    it 'rejects unknown format', {
      expect({
        BDD::Behave::DocExtractor::DocExtractor.new(:format('xml'))
      }).to.raise-error;
    }

    it 'starts with no filters configured', {
      my $ex = BDD::Behave::DocExtractor::DocExtractor.new;
      expect($ex.has-filters).to.be-falsy;
    }
  }

  describe 'markdown output', {
    it 'renders nested describe/context as ascending heading levels', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new;
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('# Calculator');
      expect($out).to.include('## addition');
      expect($out).to.include('## subtraction');
    }

    it 'renders examples as bullets under their group', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new;
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('- adds two positive numbers');
      expect($out).to.include('- handles zero');
      expect($out).to.include('- subtracts two numbers');
    }

    it 'marks pending examples with (PENDING)', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new;
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('handles overflow (PENDING)');
    }

    it 'marks skipped examples with (SKIPPED)', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new;
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('skipped one (SKIPPED)');
    }

    it 'includes tag annotations after example descriptions', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new;
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('adds two positive numbers [user-facing]');
      expect($out).to.include('subtracts two numbers [internal]');
    }

    it 'omits the suite heading when only one suite is provided', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new;
      my $out       = $extractor.extract([$suite]);

      expect($out.starts-with('# Calculator')).to.be-truthy;
    }

    it 'includes the suite heading when multiple suites are provided', {
      my $s1 = build-suite();
      my $s2 = Suite.create(
        :description('other-spec.raku'),
        :file('/tmp/other-spec.raku'.IO),
        :line(0),
      );
      my $g  = ExampleGroup.new(:description('Other'),
                                :file('/tmp/other-spec.raku'.IO), :line(1));
      $s2.add-group($g);
      $g.add-example(Example.new(
        :description('does something'),
        :file('/tmp/other-spec.raku'.IO), :line(2),
        :block({ Nil }),
      ));

      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new;
      my $out       = $extractor.extract([$s1, $s2]);

      expect($out).to.include('# demo-spec.raku');
      expect($out).to.include('# other-spec.raku');
      expect($out).to.include('## Other');
    }
  }

  describe 'html output', {
    it 'emits a full html document', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(:format<html>);
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('<!DOCTYPE html>');
      expect($out).to.include('<html>');
      expect($out).to.include('</html>');
    }

    it 'wraps groups in <section> with heading per depth', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(:format<html>);
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('<section class="group">');
      expect($out).to.include('<h2>Calculator</h2>');
      expect($out).to.include('<h3>addition</h3>');
    }

    it 'emits examples in a <ul class="examples">', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(:format<html>);
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('<ul class="examples">');
      expect($out).to.include('adds two positive numbers');
    }

    it 'marks non-passing examples with a status class and em tag', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(:format<html>);
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('class="example status-pending"');
      expect($out).to.include('<em class="status">(pending)</em>');
      expect($out).to.include('class="example status-skipped"');
    }

    it 'html-escapes descriptions', {
      my $suite = Suite.create(
        :description('s-spec.raku'),
        :file('/tmp/s-spec.raku'.IO), :line(0),
      );
      my $g = ExampleGroup.new(
        :description('Has <html> & "quotes"'),
        :file('/tmp/s-spec.raku'.IO), :line(1),
      );
      $suite.add-group($g);
      $g.add-example(Example.new(
        :description('handles >special< chars'),
        :file('/tmp/s-spec.raku'.IO), :line(2),
        :block({ Nil }),
      ));

      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(:format<html>);
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('Has &lt;html&gt; &amp; &quot;quotes&quot;');
      expect($out).to.include('handles &gt;special&lt; chars');
    }
  }

  describe 'json output', {
    it 'emits valid json with version and suites keys', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(:format<json>);
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('"version":1');
      expect($out).to.include('"suites":');
    }

    it 'represents groups recursively with file and line', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(:format<json>);
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('"description":"Calculator"');
      expect($out).to.include('"description":"addition"');
      expect($out).to.include('"description":"subtraction"');
      expect($out).to.include('"line":3');
    }

    it 'includes status flags per example', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(:format<json>);
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('"pending":true');
      expect($out).to.include('"skipped":true');
    }

    it 'includes tags array per example', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(:format<json>);
      my $out       = $extractor.extract([$suite]);

      expect($out).to.include('"tags":["user-facing"]');
      expect($out).to.include('"tags":["internal"]');
    }
  }

  describe 'filtering by tag and metadata', {
    it 'reports has-filters true when include-tags supplied', {
      my $ex = BDD::Behave::DocExtractor::DocExtractor.new(
        :include-tags(<user-facing>),
      );
      expect($ex.has-filters).to.be-truthy;
    }

    it 'include-tag drops examples without the tag', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(
        :include-tags(<user-facing>),
      );
      my $out = $extractor.extract([$suite]);

      expect($out).to.include('adds two positive numbers');
      expect($out.contains('subtracts two numbers')).to.be-falsy;
      expect($out.contains('handles overflow')).to.be-falsy;
    }

    it 'drops groups whose examples are all filtered out', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(
        :include-tags(<user-facing>),
      );
      my $out = $extractor.extract([$suite]);

      expect($out.contains('## subtraction')).to.be-falsy;
      expect($out).to.include('## addition');
    }

    it 'exclude-tag drops matching examples', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(
        :exclude-tags(<internal>),
      );
      my $out = $extractor.extract([$suite]);

      expect($out.contains('subtracts two numbers')).to.be-falsy;
      expect($out).to.include('adds two positive numbers');
    }

    it 'metadata-filters keep only matching examples', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(
        :metadata-filters(%(type => 'unit')),
      );
      my $out = $extractor.extract([$suite]);

      expect($out).to.include('adds two positive numbers');
      expect($out).to.include('handles zero');
      expect($out.contains('subtracts two numbers')).to.be-falsy;
    }

    it 'metadata-exclude-filters drop matching examples', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(
        :metadata-exclude-filters(%(type => 'unit')),
      );
      my $out = $extractor.extract([$suite]);

      expect($out.contains('adds two positive numbers')).to.be-falsy;
      expect($out.contains('handles zero')).to.be-falsy;
      expect($out).to.include('subtracts two numbers');
    }

    it 'example-patterns filter by substring match', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(
        :example-patterns(['adds two']),
      );
      my $out = $extractor.extract([$suite]);

      expect($out).to.include('adds two positive numbers');
      expect($out.contains('handles zero')).to.be-falsy;
      expect($out.contains('subtracts two numbers')).to.be-falsy;
    }

    it 'example-patterns wrapped in slashes are treated as regex', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(
        :example-patterns(['/handles\s\w+/']),
      );
      my $out = $extractor.extract([$suite]);

      expect($out).to.include('handles zero');
      expect($out).to.include('handles overflow');
      expect($out.contains('subtracts two numbers')).to.be-falsy;
    }

    it 'filtering drops the entire suite if nothing matches', {
      my $suite     = build-suite();
      my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(
        :include-tags(<no-such-tag>),
      );
      my $out = $extractor.extract([$suite]);
      expect($out.trim).to.eq('');
    }
  }
}
