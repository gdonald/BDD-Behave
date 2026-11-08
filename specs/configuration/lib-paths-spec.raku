use BDD::Behave;
use BDD::Behave::Configuration;
use Behave::Test::ProjectDir;

constant Configuration = BDD::Behave::Configuration::Configuration;

sub greeting-module(Str $greeting --> Str) {
  "unit module Greeting;\nour sub greet \{ '$greeting' \}\n";
}

sub greeting-spec(Str $expected --> Str) {
  qq:to/SPEC/;
    use BDD::Behave;
    use Greeting;

    describe 'a greeting', \{
      it 'comes from the configured path', \{
        expect(Greeting::greet()).to.eq('$expected');
      \}
    \}
    SPEC
}

sub search-path-spec(--> Str) {
  q:to/SPEC/;
    use BDD::Behave;

    describe 'the module search path', {
      it 'starts with the configured path', {
        expect($*REPO.repo-chain.first(CompUnit::Repository::FileSystem).prefix.basename).to.eq('app');
      }

      it 'does not pass the inherited path marker to processes the spec starts', {
        expect(%*ENV<BEHAVE_INHERITED_LIB_PATHS>:exists).to.eq(False);
      }
    }
    SPEC
}

sub behave-config(Str $paths --> Str) {
  "use BDD::Behave::Configuration;\nconfigure-behave -> \$c \{ \$c.lib($paths) \};\n";
}

describe 'the lib setting', {
  describe 'on a Configuration', {
    let(:config, { Configuration.new });

    it 'appends paths across calls', {
      config.lib('app');
      config.lib('specs/lib', 'vendor');

      expect(config.lib-paths.List).to.eq(<app specs/lib vendor>.List);
    }

    context 'when merged', {
      let(:user-config, { Configuration.new.lib('user-lib') });
      let(:project-config, { Configuration.new.lib('app') });

      it 'keeps the user paths ahead of the project paths', {
        expect(user-config.merge(project-config).lib-paths.List).to.eq(<user-lib app>.List);
      }
    }
  }

  describe 'resolve-lib-paths', {
    it 'defaults to lib when no path is configured', {
      expect(BDD::Behave::Configuration::resolve-lib-paths(Configuration.new)).to.eq(('lib',));
    }

    context 'with a path configured twice', {
      let(:config, { Configuration.new.lib('app', 'specs/lib', 'app') });

      it 'returns each configured path once', {
        expect(BDD::Behave::Configuration::resolve-lib-paths(config)).to.eq(<app specs/lib>.List);
      }
    }
  }

  describe 'running behave in a project', {
    context 'whose code is under app with lib app in .behave', {
      let(:files, {
        %(
          '.behave'                   => behave-config("'app'"),
          'app/Greeting.rakumod'      => greeting-module('from app'),
          'specs/greeting-spec.raku'  => greeting-spec('from app'),
          'specs/second-spec.raku'    => greeting-spec('from app'),
        );
      });

      it 'loads the code in the same process', {
        expect(run-project(files, 'specs/greeting-spec.raku')<exit>).to.eq(0);
      }

      it 'loads the code in parallel workers', {
        expect(run-project(files, '--parallel', '2', 'specs/greeting-spec.raku', 'specs/second-spec.raku')<exit>).to.eq(0);
      }
    }

    context 'with lib app in .behave and a lib directory present', {
      let(:files, {
        %(
          '.behave'                  => behave-config("'app'"),
          'app/Greeting.rakumod'     => greeting-module('from app'),
          'lib/Other.rakumod'        => "unit module Other;\n",
          'specs/chain-spec.raku'    => search-path-spec(),
          'specs/second-spec.raku'   => search-path-spec(),
        );
      });

      it 'searches app first in the same process', {
        expect(run-project(files, 'specs/chain-spec.raku')<exit>).to.eq(0);
      }

      it 'searches app first in parallel workers', {
        expect(run-project(files, '--parallel', '2', 'specs/chain-spec.raku', 'specs/second-spec.raku')<exit>).to.eq(0);
      }
    }

    context 'with no .behave and code under lib', {
      let(:files, {
        %(
          'lib/Greeting.rakumod'     => greeting-module('from lib'),
          'specs/greeting-spec.raku' => greeting-spec('from lib'),
        );
      });

      it 'loads the code from lib', {
        expect(run-project(files, 'specs/greeting-spec.raku')<exit>).to.eq(0);
      }
    }

    context 'with lib app in .behave and code only under lib', {
      let(:files, {
        %(
          '.behave'                  => behave-config("'app'"),
          'lib/Greeting.rakumod'     => greeting-module('from lib'),
          'specs/greeting-spec.raku' => greeting-spec('from lib'),
        );
      });

      it 'does not search lib', {
        my %result = run-project(files, 'specs/greeting-spec.raku');

        expect(%result<out> ~ %result<err>).to.include('Could not find Greeting');
      }
    }

    context 'with two configured paths that both hold the module', {
      let(:files, {
        %(
          '.behave'                  => behave-config("'first', 'second'"),
          'first/Greeting.rakumod'   => greeting-module('from first'),
          'second/Greeting.rakumod'  => greeting-module('from second'),
          'specs/greeting-spec.raku' => greeting-spec('from second'),
        );
      });

      it 'searches the last path first, as use lib does', {
        expect(run-project(files, 'specs/greeting-spec.raku')<exit>).to.eq(0);
      }
    }

    context 'with a configured path that -I already put on the search path', {
      let(:files, {
        %(
          '.behave'                  => behave-config("'second'"),
          'first/Greeting.rakumod'   => greeting-module('from first'),
          'second/Greeting.rakumod'  => greeting-module('from second'),
          'specs/greeting-spec.raku' => greeting-spec('from first'),
        );
      });

      it 'leaves that path where -I put it', {
        expect(run-project(files, 'specs/greeting-spec.raku', :include<first second>)<exit>).to.eq(0);
      }
    }

    context 'with an absolute path in .behave', {
      let(:files, {
        %(
          '.behave'                  => behave-config('$*CWD.add(\'app\').absolute'),
          'app/Greeting.rakumod'     => greeting-module('from app'),
          'specs/greeting-spec.raku' => greeting-spec('from app'),
        );
      });

      it 'loads the code from that path', {
        expect(run-project(files, 'specs/greeting-spec.raku')<exit>).to.eq(0);
      }
    }
  }
}
