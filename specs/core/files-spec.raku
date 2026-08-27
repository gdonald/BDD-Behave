use BDD::Behave;
use BDD::Behave::Files;
use Test::Output;

sub make-tree(--> IO::Path) {
  my $base = $*TMPDIR.add("behave-files-spec-{$*PID}-{(now * 1e6).Int.base(36)}");
  $base.mkdir;
  $base.add('nested').mkdir;
  $base.add('alpha-spec.raku').spurt('');
  $base.add('beta-spec.raku').spurt('');
  $base.add('README.md').spurt('');
  $base.add('nested').add('gamma-spec.raku').spurt('');
  $base;
}

sub remove-tree(IO::Path $base --> Nil) {
  return unless $base.e;
  for $base.dir -> $entry {
    remove-tree($entry) if $entry.d;
    $entry.unlink if $entry.f;
  }
  $base.rmdir;
}

describe 'the spec files a run collects', {
  let(:tree, { make-tree() });

  after-each { remove-tree(tree()) }

  context 'given a directory', {
    it 'collects the spec files inside it', {
      expect(Files.list([tree().absolute]).grep(*.ends-with('alpha-spec.raku')).elems).to.be(1);
    }

    it 'walks into the directories below it', {
      expect(Files.list([tree().absolute]).grep(*.ends-with('gamma-spec.raku')).elems).to.be(1);
    }

    it 'leaves files that are not specs alone', {
      expect(Files.list([tree().absolute]).grep(*.ends-with('README.md')).elems).to.be(0);
    }
  }

  context 'given a spec file by name', {
    it 'collects that file', {
      my $file = tree().add('alpha-spec.raku').absolute;

      expect(Files.list([$file]).list).to.eq(($file,));
    }
  }

  context 'given a spec file with a line number', {
    it 'keeps the line number with the file', {
      my $target = tree().add('alpha-spec.raku').absolute ~ ':12';

      expect(Files.list([$target]).list).to.eq(($target,));
    }
  }

  context 'given a path that is neither a spec file nor a directory', {
    it 'collects nothing from it', {
      my @collected;
      stderr-from({ @collected = Files.list([tree().add('README.md').absolute]) });

      expect(@collected.elems).to.be(0);
    }

    it 'warns that it is ignoring the path', {
      expect(stderr-from({ Files.list([tree().add('README.md').absolute]) }))
        .to.include('is not a spec file or directory; ignoring');
    }
  }

  context 'given nothing at all', {
    it 'falls back to the specs directory the class names', {
      expect(Files.specs-dir).to.eq('specs');
    }
  }
}
