use lib 'lib';
use BDD::Behave;
use META6;
use URI;

sub find-rakumod(IO::Path $dir) {
  gather for $dir.dir {
    when .d                      { .take for find-rakumod($_) }
    when .extension eq 'rakumod' { .take }
  }
}

my $meta-file      = 'META6.json'.IO;
my $meta           = META6.new(file => $meta-file);
my @provides       = $meta.provides.pairs.sort(*.key);
my %provided-paths = $meta.provides.values.Set;
my @lib-rakumod    = find-rakumod('lib'.IO).map(*.relative).sort;

describe 'META6.json', {
  it 'exists at the project root', {
    expect($meta-file.e).to.be-truthy;
  }

  context 'name', {
    it "uses '::' as the module separator", {
      expect($meta.name).to.match(/\:\:/);
    }

    it 'does not contain a hyphen', {
      expect($meta.name).to.not.match(/\-/);
    }
  }

  context 'version', {
    it 'is defined', {
      expect($meta.version).to.not.be-nil;
    }

    it 'has no wildcard parts', {
      expect($meta.version.parts.grep('*').elems).to.be(0);
    }
  }

  context 'description', {
    it 'is non-empty', {
      expect($meta.description // '').to.match(/\S/);
    }
  }

  context 'authors', {
    it 'has at least one entry', {
      expect($meta.authors.elems).to.be-greater-than(0);
    }

    it "uses 'authors' rather than the deprecated 'author'", {
      expect($meta.author).to.be-nil;
    }
  }

  context 'auth', {
    it 'is in zef:<user> format', {
      expect($meta.auth // '').to.match(/^ 'zef:' \S+ $/);
    }
  }

  context 'license', {
    it 'is non-empty', {
      expect($meta.license // '').to.match(/\S/);
    }
  }

  context 'source-url', {
    it 'is defined', {
      expect($meta.source-url).to.not.be-nil;
    }

    it 'parses as a URI with a host', {
      expect(URI.new($meta.source-url).host).to.be-truthy;
    }
  }

  context 'provides', {
    it 'has at least one entry', {
      expect(@provides.elems).to.be-greater-than(0);
    }

    context 'declared paths exist on disk', {
      for @provides -> $p {
        it "{$p.key} → {$p.value}", {
          expect($p.value.IO.e).to.be-truthy;
        }
      }
    }

    context 'every lib/**/*.rakumod is declared', {
      for @lib-rakumod -> $rel {
        it $rel, {
          expect(%provided-paths{$rel}:exists).to.be-truthy;
        }
      }
    }
  }
}
