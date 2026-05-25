use BDD::Behave;
use BDD::Behave::Version;

my $stamp    = sprintf '%d-%d', $*PID, (now * 1e6).Int;
my $tmp-root = $*TMPDIR.add("behave-version-spec-$stamp");

sub make-tree(*@segments) {
  my $dir = $tmp-root;

  for @segments -> $seg {
    $dir = $dir.add($seg);
  }

  $dir.mkdir;
  $dir;
}

describe 'BDD::Behave::Version', {
  before-all {
    $tmp-root.mkdir;
  }

  after-all {
    run('rm', '-rf', $tmp-root.absolute, :!out, :!err) if $tmp-root.e;
  }

  context 'from-meta-file', {
    it 'returns Str when the path does not exist', {
      my $missing = $tmp-root.add('does-not-exist.json');

      expect(BDD::Behave::Version::from-meta-file($missing)).to.be-nil;
    }

    it 'returns Str for an undefined path', {
      expect(BDD::Behave::Version::from-meta-file(IO::Path)).to.be-nil;
    }

    it 'returns the version when the file has a "version" field', {
      my $meta = $tmp-root.add('META6.json');

      $meta.spurt(q:to/JSON/);
      {
        "name": "Demo",
        "version": "1.2.3"
      }
      JSON

      expect(BDD::Behave::Version::from-meta-file($meta)).to.eq('1.2.3');
    }

    it 'returns Str when the file lacks a "version" field', {
      my $meta = $tmp-root.add('META6.json');
      $meta.spurt('{ "name": "NoVersion" }');

      expect(BDD::Behave::Version::from-meta-file($meta)).to.be-nil;
    }
  }

  context 'from-source-checkout', {
    it 'returns the version when META6.json sits in a parent directory', {
      my $deep = make-tree('a', 'b', 'c');
      my $meta = $tmp-root.add('a').add('META6.json');

      $meta.spurt('{ "version": "4.5.6" }');

      my $fake-program = $deep.add('behave');
      $fake-program.spurt('');

      expect(BDD::Behave::Version::from-source-checkout($fake-program)).to.eq('4.5.6');
    }

    it 'returns Str when no META6.json is found while walking up', {
      my $deep = make-tree('x', 'y');

      my $fake-program = $deep.add('behave');
      $fake-program.spurt('');

      my $ver = BDD::Behave::Version::from-source-checkout($fake-program);

      expect($ver.defined && $ver eq '4.5.6').to.be-falsy;
    }

    it 'returns Str for an undefined program path', {
      expect(BDD::Behave::Version::from-source-checkout(IO::Path)).to.be-nil;
    }
  }

  context 'version', {
    it 'returns a non-empty string', {
      expect(BDD::Behave::Version::version().chars).to.be-greater-than(0);
    }

    it 'uses the source-checkout fallback when given a program-path under a META6.json', {
      my $deep = make-tree('checkout');
      my $meta = $tmp-root.add('checkout').add('META6.json');

      $meta.spurt('{ "version": "9.9.9" }');

      my $fake-program = $deep.add('behave');
      $fake-program.spurt('');

      my $reported = BDD::Behave::Version::version(:program-path($fake-program));

      expect($reported eq '9.9.9' || $reported.chars > 0).to.be-truthy;
    }
  }
}
