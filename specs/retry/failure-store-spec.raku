use BDD::Behave;
use BDD::Behave::FailureStore;

sub fresh-file(--> IO::Path) {
  my $path = $*TMPDIR.add("behave-failure-store-{$*PID}-{(now * 1e6).Int.base(36)}.txt");
  $path.unlink if $path.e;
  $path;
}

describe 'BDD::Behave::FailureStore', {
  describe 'read-failures', {
    it 'returns empty list when the file does not exist', {
      my $path = fresh-file();
      expect(BDD::Behave::FailureStore::read-failures($path).elems).to.be(0);
    }

    it 'reads one location per line', {
      my $path = fresh-file();
      LEAVE { $path.unlink if $path.e }
      $path.spurt: "specs/a-spec.raku:10\nspecs/b-spec.raku:20\n";
      my @out = BDD::Behave::FailureStore::read-failures($path);
      expect(@out.elems).to.be(2);
      expect(@out[0]).to.be('specs/a-spec.raku:10');
      expect(@out[1]).to.be('specs/b-spec.raku:20');
    }

    it 'ignores blank lines and # comments', {
      my $path = fresh-file();
      LEAVE { $path.unlink if $path.e }
      $path.spurt: "# Header comment\nspecs/a-spec.raku:10\n\nspecs/b-spec.raku:20\n";
      my @out = BDD::Behave::FailureStore::read-failures($path);
      expect(@out.elems).to.be(2);
    }
  }

  describe 'merge-failures', {
    it 'removes ran-and-passed entries', {
      my @existing = ('specs/a:1', 'specs/b:2');
      my @ran      = ('specs/a:1', 'specs/b:2');
      my @failed   = ('specs/a:1',);
      my @result   = BDD::Behave::FailureStore::merge-failures(@existing, @ran, @failed);
      expect(@result.elems).to.be(1);
      expect(@result[0]).to.be('specs/a:1');
    }

    it 'preserves entries that did not run this time', {
      my @existing = ('specs/a:1', 'specs/other:99');
      my @ran      = ('specs/a:1',);
      my @failed   = ('specs/a:1',);
      my @result   = BDD::Behave::FailureStore::merge-failures(@existing, @ran, @failed);
      expect(@result.elems).to.be(2);
      expect(@result.grep(* eq 'specs/other:99').elems).to.be(1);
    }

    it 'adds new failure locations', {
      my @existing = ();
      my @ran      = ('specs/x:7', 'specs/y:9');
      my @failed   = ('specs/x:7',);
      my @result   = BDD::Behave::FailureStore::merge-failures(@existing, @ran, @failed);
      expect(@result.elems).to.be(1);
      expect(@result[0]).to.be('specs/x:7');
    }

    it 'returns unique entries even when failure list has duplicates', {
      my @existing = ();
      my @ran      = ('specs/x:7',);
      my @failed   = ('specs/x:7', 'specs/x:7');
      my @result   = BDD::Behave::FailureStore::merge-failures(@existing, @ran, @failed);
      expect(@result.elems).to.be(1);
    }
  }

  describe 'write-failures', {
    it 'writes one location per line with trailing newline', {
      my $path = fresh-file();
      LEAVE { $path.unlink if $path.e }
      BDD::Behave::FailureStore::write-failures($path, (), ('specs/x:1', 'specs/y:2'));
      expect($path.slurp).to.be("specs/x:1\nspecs/y:2\n");
    }

    it 'writes an empty file when there are no failures', {
      my $path = fresh-file();
      LEAVE { $path.unlink if $path.e }
      BDD::Behave::FailureStore::write-failures($path, ('specs/x:1',), ());
      expect($path.e).to.be-truthy;
      expect($path.slurp).to.be('');
    }
  }
}
