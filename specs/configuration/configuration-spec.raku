use BDD::Behave;
use BDD::Behave::Configuration;

constant Configuration = BDD::Behave::Configuration::Configuration;
constant ConfigInclude = BDD::Behave::Configuration::ConfigInclude;
constant ConfigHook    = BDD::Behave::Configuration::ConfigHook;

my class SampleHelpers {
  method greet { 'hello' }
}

describe 'BDD::Behave::Configuration', {
  describe 'fresh Configuration', {
    it 'starts with every scalar undefined', {
      my $c = Configuration.new;
      expect($c.format.defined).to.be-falsy;
      expect($c.order.defined).to.be-falsy;
      expect($c.seed.defined).to.be-falsy;
      expect($c.fail-fast.defined).to.be-falsy;
      expect($c.verbose.defined).to.be-falsy;
      expect($c.aggregate-failures.defined).to.be-falsy;
    }

    it 'starts with every accumulator empty', {
      my $c = Configuration.new;
      expect($c.include-tags.elems).to.be(0);
      expect($c.exclude-tags.elems).to.be(0);
      expect($c.example-patterns.elems).to.be(0);
      expect($c.only-locations.elems).to.be(0);
      expect($c.spec-paths.elems).to.be(0);
      expect($c.includes.elems).to.be(0);
      expect($c.hooks.elems).to.be(0);
      expect($c.metadata-filters.elems).to.be(0);
      expect($c.metadata-exclude-filters.elems).to.be(0);
      expect($c.match-filters.elems).to.be(0);
    }
  }

  describe 'scalar setters', {
    it 'stores a format choice', {
      my $c = Configuration.new;
      $c.format = 'documentation';
      expect($c.format).to.eq('documentation');
    }

    it 'stores an order and seed', {
      my $c = Configuration.new;
      $c.order = 'defined';
      $c.seed  = 42;
      expect($c.order).to.eq('defined');
      expect($c.seed).to.eq(42);
    }
  }

  describe 'list accumulators', {
    it 'appends include-tags across calls', {
      my $c = Configuration.new;
      $c.include-tag('focus');
      $c.include-tag('slow', 'wip');
      expect($c.include-tags.List).to.eq(<focus slow wip>.List);
    }

    it 'appends exclude-tags', {
      my $c = Configuration.new;
      $c.exclude-tag('db');
      expect($c.exclude-tags.List).to.eq(<db>.List);
    }

    it 'appends example patterns and only-locations', {
      my $c = Configuration.new;
      $c.example-pattern('login');
      $c.only-location('specs/foo.raku:12');
      expect($c.example-patterns.List).to.eq(<login>.List);
      expect($c.only-locations.List).to.eq(('specs/foo.raku:12',).List);
    }

    it 'appends spec paths', {
      my $c = Configuration.new;
      $c.include-spec('specs/');
      expect($c.spec-paths.List).to.eq(<specs/>.List);
    }
  }

  describe '.include for helpers', {
    it 'registers a class with default key (short class name)', {
      my $c = Configuration.new;
      $c.include(SampleHelpers);
      expect($c.includes.elems).to.eq(1);
      expect($c.includes[0]).to.be-a(ConfigInclude);
      expect($c.includes[0].key).to.eq('SampleHelpers');
    }

    it 'honors :as<name> alias', {
      my $c = Configuration.new;
      $c.include(SampleHelpers, :as<helpers>);
      expect($c.includes[0].key).to.eq('helpers');
    }
  }

  describe 'global hooks', {
    it 'stores a before-all hook', {
      my $c = Configuration.new;
      $c.before-all({ Nil });
      expect($c.hooks.elems).to.eq(1);
      expect($c.hooks[0].phase).to.eq('before-all');
    }

    it 'stores an after-all hook', {
      my $c = Configuration.new;
      $c.after-all({ Nil });
      expect($c.hooks[0].phase).to.eq('after-all');
    }

    it 'stores before-each / after-each / around-each hooks', {
      my $c = Configuration.new;
      $c.before-each({ Nil });
      $c.after-each({ Nil });
      $c.around-each(-> &n { n() });
      my @phases = $c.hooks.map(*.phase);
      expect(@phases.List).to.eq(<before-each after-each around-each>.List);
    }

    it 'hooks-for filters by phase', {
      my $c = Configuration.new;
      $c.before-all({ Nil });
      $c.after-all({ Nil });
      expect($c.hooks-for('before-all').elems).to.eq(1);
      expect($c.hooks-for('after-all').elems).to.eq(1);
      expect($c.hooks-for('before-each').elems).to.eq(0);
    }
  }

  describe 'metadata filters', {
    it 'stores .filter pairs', {
      my $c = Configuration.new;
      $c.filter(:db);
      $c.filter(:type<unit>);
      expect($c.metadata-filters<db>).to.be-truthy;
      expect($c.metadata-filters<type>).to.eq('unit');
    }

    it 'stores .exclude-filter pairs', {
      my $c = Configuration.new;
      $c.exclude-filter(:slow);
      expect($c.metadata-exclude-filters<slow>).to.be-truthy;
    }

    it 'stores filter-run-when-matching as ordered pairs', {
      my $c = Configuration.new;
      $c.filter-run-when-matching('focus');
      $c.filter-run-when-matching(:wip);
      expect($c.match-filters.elems).to.eq(2);
      expect($c.match-filters[0].key).to.eq('focus');
      expect($c.match-filters[1].key).to.eq('wip');
    }
  }

  describe 'merge precedence', {
    it 'lets the other config override scalar settings', {
      my $base  = Configuration.new;
      $base.format = 'progress';
      $base.order  = 'defined';

      my $over  = Configuration.new;
      $over.format = 'documentation';

      my $m = $base.merge($over);
      expect($m.format).to.eq('documentation');
      expect($m.order).to.eq('defined');
    }

    it 'keeps base scalars when other leaves them undefined', {
      my $base  = Configuration.new;
      $base.seed = 7;

      my $over  = Configuration.new;
      my $m = $base.merge($over);
      expect($m.seed).to.eq(7);
    }

    it 'appends list accumulators (base first, then other)', {
      my $base = Configuration.new;
      $base.include-tag('a');

      my $over = Configuration.new;
      $over.include-tag('b');

      my $m = $base.merge($over);
      expect($m.include-tags.List).to.eq(<a b>.List);
    }

    it 'merges metadata-filters with other winning on conflict', {
      my $base = Configuration.new;
      $base.filter(:k<base>);

      my $over = Configuration.new;
      $over.filter(:k<over>);

      my $m = $base.merge($over);
      expect($m.metadata-filters<k>).to.eq('over');
    }

    it 'accumulates hooks from both configs', {
      my $base = Configuration.new;
      $base.before-all({ 'a' });

      my $over = Configuration.new;
      $over.before-all({ 'b' });

      my $m = $base.merge($over);
      expect($m.hooks-for('before-all').elems).to.eq(2);
    }
  }

  describe 'defaults()', {
    it 'returns a Configuration with sane built-in defaults', {
      my $d = BDD::Behave::Configuration::defaults();
      expect($d.format).to.eq('progress');
      expect($d.order).to.eq('random');
      expect($d.fail-fast).to.eq(0);
      expect($d.verbose).to.be-falsy;
      expect($d.benchmark-iterations).to.eq(1);
      expect($d.benchmark-format).to.eq('text');
    }
  }

  describe 'load-file', {
    it 'returns an empty config for a non-existent file', {
      my $path = $*TMPDIR.add("behave-missing-{$*PID}-{(now * 1e6).Int}.behave");
      my $c = BDD::Behave::Configuration::load-file($path);
      expect($c).to.be-a(Configuration);
      expect($c.format.defined).to.be-falsy;
    }

    it 'reads settings via configure-behave', {
      my $path = $*TMPDIR.add("behave-load-{$*PID}-{(now * 1e6).Int}.behave");
      $path.spurt(q:to/CONFIG/);
        use BDD::Behave::Configuration;
        configure-behave -> $c {
          $c.format = 'tap';
          $c.order  = 'defined';
          $c.include-tag('focus');
        };
      CONFIG
      my $c = BDD::Behave::Configuration::load-file($path);
      $path.unlink;
      expect($c.format).to.eq('tap');
      expect($c.order).to.eq('defined');
      expect($c.include-tags.List).to.eq(<focus>.List);
    }

    it 'raises a helpful error when the config file dies', {
      my $path = $*TMPDIR.add("behave-bad-{$*PID}-{(now * 1e6).Int}.behave");
      $path.spurt('die "boom from config";');
      expect({
        BDD::Behave::Configuration::load-file($path);
      }).to.raise-error(/'boom from config'/);
      $path.unlink;
    }
  }

  describe 'configure-behave outside a load', {
    it 'dies when called without an active config', {
      expect({
        BDD::Behave::Configuration::configure-behave(-> $ { Nil });
      }).to.raise-error(/'outside of a .behave config file'/);
    }
  }
}
