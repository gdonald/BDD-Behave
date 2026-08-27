use BDD::Behave;
use BDD::Behave::Configuration;
use BDD::Behave::SpecTree;

constant Configuration = BDD::Behave::Configuration::Configuration;
constant ConfigHook    = BDD::Behave::Configuration::ConfigHook;
constant Example       = BDD::Behave::SpecTree::Example;

sub example-with(%metadata --> Example) {
  Example.new(
    :description('an example'),
    :file('/abs/spec.raku'.IO),
    :line(7),
    :block(sub { }),
    :metadata(%metadata),
  );
}

sub hook-with(*%filter --> ConfigHook) {
  ConfigHook.new(:phase('before-each'), :block(sub { }), |%filter);
}

describe 'a configured hook deciding whether it applies to an example', {
  context 'given no filter at all', {
    it 'applies to any example', {
      expect(hook-with().matches-example(example-with({ }))).to.be-truthy;
    }
  }

  context 'given a tag to include', {
    it 'applies to an example carrying it', {
      expect(hook-with(:tag('slow')).matches-example(example-with({ tags => ['slow'] })))
        .to.be-truthy;
    }

    it 'does not apply to an example without it', {
      expect(hook-with(:tag('slow')).matches-example(example-with({ tags => ['fast'] })))
        .to.be-falsy;
    }
  }

  context 'given a tag to exclude', {
    it 'does not apply to an example carrying it', {
      expect(hook-with(:exclude-tag('slow')).matches-example(example-with({ tags => ['slow'] })))
        .to.be-falsy;
    }

    it 'applies to an example without it', {
      expect(hook-with(:exclude-tag('slow')).matches-example(example-with({ tags => ['fast'] })))
        .to.be-truthy;
    }
  }

  context 'given a metadata value to match', {
    it 'applies to an example carrying that value', {
      expect(hook-with(:meta({ area => 'db' })).matches-example(example-with({ area => 'db' })))
        .to.be-truthy;
    }

    it 'does not apply to an example carrying another value', {
      expect(hook-with(:meta({ area => 'db' })).matches-example(example-with({ area => 'http' })))
        .to.be-falsy;
    }

    it 'does not apply to an example carrying nothing for the key', {
      expect(hook-with(:meta({ area => 'db' })).matches-example(example-with({ })))
        .to.be-falsy;
    }
  }

  context 'given a metadata flag to match', {
    it 'applies to an example carrying the flag', {
      expect(hook-with(:meta({ slow => True })).matches-example(example-with({ slow => True })))
        .to.be-truthy;
    }

    it 'does not apply to an example carrying the flag turned off', {
      expect(hook-with(:meta({ slow => True })).matches-example(example-with({ slow => False })))
        .to.be-falsy;
    }
  }
}

describe 'the paths a configuration collects for coverage', {
  let(:config, { Configuration.new });

  it 'keeps the paths to include', {
    config().coverage-include-path('lib/', 'bin/');

    expect(config().coverage-include.join(',')).to.eq('lib/,bin/');
  }

  it 'keeps the paths to exclude', {
    config().coverage-exclude-path('vendor/');

    expect(config().coverage-exclude.join(',')).to.eq('vendor/');
  }

  it 'hands itself back so calls can be chained', {
    expect(config().coverage-include-path('lib/')).to.be(config());
  }
}

describe 'merging two configurations', {
  let(:merged, {
    my $base = Configuration.new;
    $base.metadata-exclude-filters<area> = 'db';

    my $other = Configuration.new;
    $other.metadata-exclude-filters<speed> = 'slow';

    $base.merge($other);
  });

  it 'keeps an exclusion from the first', {
    expect(merged().metadata-exclude-filters<area>).to.eq('db');
  }

  it 'keeps an exclusion from the second', {
    expect(merged().metadata-exclude-filters<speed>).to.eq('slow');
  }
}

describe 'where behave looks for a configuration file', {
  it 'looks beside the directory it was given', {
    expect(BDD::Behave::Configuration::project-config-path(:base('/some/project'.IO)).absolute)
      .to.eq('/some/project/.behave');
  }

  it 'looks in the working directory by default', {
    expect(BDD::Behave::Configuration::project-config-path().basename).to.eq('.behave');
  }

  it 'looks in the home directory of the user', {
    expect(BDD::Behave::Configuration::user-config-path().basename).to.eq('.behave');
  }
}
