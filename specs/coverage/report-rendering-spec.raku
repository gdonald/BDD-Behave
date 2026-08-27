use BDD::Behave;
use BDD::Behave::Coverage;

constant Coverage = BDD::Behave::Coverage;

# A small project of one source file, plus a hit log naming some of its lines,
# is enough to drive every report format end to end.
sub project(--> IO::Path) {
  my $root = $*TMPDIR.add("behave-coverage-report-{$*PID}-{(now * 1e6).Int.base(36)}");
  $root.mkdir;
  $root.add('lib').mkdir;

  $root.add('lib').add('Sample.rakumod').spurt(q:to/SOURCE/);
  unit module Sample;

  our sub classify(Int $n --> Str) {
    if $n > 10 {
      'big';
    } else {
      'small';
    }
  }

  our sub untouched(--> Str) {
    'never called';
  }
  SOURCE

  $root;
}

sub remove-tree(IO::Path $node --> Nil) {
  return unless $node.e;
  if $node.d {
    remove-tree($_) for $node.dir;
    $node.rmdir;
  } else {
    $node.unlink;
  }
}

sub log-for(IO::Path $root, *@lines --> IO::Path) {
  my $log = $root.add('coverage.log');
  my $source = $root.add('lib').add('Sample.rakumod').absolute;
  $log.spurt(@lines.map({ "HIT  $source  $_" }).join("\n") ~ "\n");
  $log;
}

sub options-for(*%named --> Coverage::CoverageOptions) {
  my $opts = Coverage::CoverageOptions.new(|%named);
  $opts;
}

sub report-of(IO::Path $root, *%named) {
  my $opts = options-for(|%named);
  $opts.include-path($root.add('lib').absolute);

  Coverage::build-report(log-for($root, 4, 5, 11), $opts, $root);
}

describe 'a coverage report built from a hit log', {
  let(:root, { project() });
  let(:report, { report-of(root()) });

  after-each { remove-tree(root()) }

  it 'holds the source file it covered', {
    expect(report().files.elems).to.be(1);
  }

  it 'names the file by its path inside the project', {
    expect(report().files[0].display-path).to.eq('lib/Sample.rakumod');
  }

  it 'counts the executable lines that were hit', {
    expect(report().files[0].covered-lines).to.be(2);
  }

  it 'leaves out a hit on a line that is not executable', {
    expect(report().files[0].covered-line-numbers.grep(* == 11).elems).to.be(0);
  }

  it 'reports a percentage below a hundred', {
    expect(report().overall-percentage < 100).to.be-truthy;
  }

  it 'reports no branches when branch tracking was off', {
    expect(report().overall-branch-percentage).to.be(100e0);
  }
}

describe 'a coverage report tracking branches', {
  let(:root, { project() });
  let(:report, { report-of(root(), :branch) });

  after-each { remove-tree(root()) }

  it 'finds the branching lines of the file', {
    expect(report().files[0].total-branches > 0).to.be-truthy;
  }

  it 'reports a branch percentage for the file', {
    expect(report().files[0].branch-percentage <= 100).to.be-truthy;
  }

  it 'reports a branch percentage for the run', {
    expect(report().overall-branch-percentage <= 100).to.be-truthy;
  }
}

describe 'rendering a coverage report', {
  let(:root, { project() });
  let(:report, { report-of(root(), :branch) });

  after-each { remove-tree(root()) }

  it 'writes a text table', {
    expect(Coverage::render-report(report(), 'text', :color(False)))
      .to.include('lib/Sample.rakumod');
  }

  it 'writes a text table in colour', {
    expect(Coverage::render-report(report(), 'text', :color(True)))
      .to.include('lib/Sample.rakumod');
  }

  it 'writes a branch line into the text table', {
    expect(Coverage::render-report(report(), 'text', :color(False))).to.include('Branches:');
  }

  it 'writes json', {
    expect(Coverage::render-report(report(), 'json')).to.include('"files"');
  }

  it 'writes the branch counts into the json', {
    expect(Coverage::render-report(report(), 'json')).to.include('total-branches');
  }

  it 'writes lcov', {
    expect(Coverage::render-report(report(), 'lcov')).to.include('SF:');
  }

  it 'writes the branch records into the lcov', {
    expect(Coverage::render-report(report(), 'lcov')).to.include('BRDA:');
  }

  it 'writes cobertura', {
    expect(Coverage::render-report(report(), 'cobertura')).to.include('<coverage');
  }

  it 'refuses to write html as a single string', {
    expect({ Coverage::render-report(report(), 'html') })
      .to.raise-error(/'writes a directory tree'/);
  }

  it 'refuses a format it does not know', {
    expect({ Coverage::render-report(report(), 'yaml') })
      .to.raise-error(/'Unknown coverage format'/);
  }
}

describe 'writing a coverage report as a tree of html pages', {
  let(:root, { project() });
  let(:out-dir, { root().add('html') });

  before-each {
    Coverage::write-html-tree(report-of(root(), :branch, :counts), out-dir());
  }

  after-each { remove-tree(root()) }

  it 'writes an index page', {
    expect(out-dir().add('index.html').e).to.be-truthy;
  }

  it 'writes a stylesheet', {
    expect(out-dir().add('style.css').e).to.be-truthy;
  }

  it 'writes the rules the report needs into the stylesheet', {
    expect(out-dir().add('style.css').slurp).to.include('.src-line.hit');
  }

  it 'writes one page per source file', {
    expect(out-dir().dir.grep(*.basename.ends-with('-rakumod.html')).elems).to.be(1);
  }

  it 'lists the file on the index page', {
    expect(out-dir().add('index.html').slurp).to.include('lib/Sample.rakumod');
  }

  it 'carries the sorting script on the index page', {
    expect(out-dir().add('index.html').slurp).to.include('coverage-table');
  }

  it 'marks the covered lines on the file page', {
    expect(out-dir().dir.grep(*.basename.ends-with('-rakumod.html'))[0].slurp)
      .to.include('src-line hit');
  }

  it 'shows the hit counts when they were tracked', {
    expect(out-dir().dir.grep(*.basename.ends-with('-rakumod.html'))[0].slurp)
      .to.include('class="hits"');
  }
}

describe 'reading a coverage log from a handle', {
  let(:root, { project() });

  after-each { remove-tree(root()) }

  it 'collects the same hits the file would give', {
    my $log = log-for(root(), 4, 5);
    my $handle = $log.open(:r);
    my %hits = Coverage::parse-coverage-stream($handle);
    $handle.close;

    expect(%hits.values[0].keys.elems).to.be(2);
  }
}

describe 'collecting the source files of a project', {
  let(:root, { project() });

  after-each { remove-tree(root()) }

  it 'takes the modules under the directory', {
    expect(Coverage::find-source-files(root().add('lib')).elems).to.be(1);
  }

  it 'takes the files named by an include path', {
    expect(
      Coverage::enumerate-include-files((root().add('lib').absolute,), (), root()).elems,
    ).to.be(1);
  }

  it 'leaves out a file named by an exclude path', {
    expect(
      Coverage::enumerate-include-files(
        (root().add('lib').absolute,), ('Sample',), root(),
      ).elems,
    ).to.be(0);
  }
}

describe 'comparing a report against a baseline', {
  let(:root, { project() });

  after-each { remove-tree(root()) }

  sub baseline-of(IO::Path $root, *@lines --> IO::Path) {
    my $opts = options-for();
    $opts.include-path($root.add('lib').absolute);

    my $report = Coverage::build-report(log-for($root, |@lines), $opts, $root);
    my $path = $root.add('baseline.json');
    $path.spurt(Coverage::render-json($report));
    $path;
  }

  it 'reports coverage that went up', {
    my $baseline = baseline-of(root(), 4);
    my $diff = Coverage::compute-diff(report-of(root()), $baseline);

    expect($diff.delta > 0).to.be-truthy;
  }

  it 'names the file that improved', {
    my $baseline = baseline-of(root(), 4);
    my $diff = Coverage::compute-diff(report-of(root()), $baseline);

    expect(Coverage::render-diff($diff)).to.include('Improved files:');
  }

  it 'reports coverage that went down', {
    my $baseline = baseline-of(root(), 4, 5, 11, 12);
    my $diff = Coverage::compute-diff(report-of(root()), $baseline);

    expect(Coverage::render-diff($diff)).to.include('Regressed files:');
  }

  it 'counts the lines that are newly covered', {
    my $baseline = baseline-of(root(), 4);
    my $diff = Coverage::compute-diff(report-of(root()), $baseline);

    expect(Coverage::render-diff($diff)).to.include('Newly covered lines:');
  }
}

describe 'reading a baseline written with escapes in its strings', {
  it 'reads an escaped quote', {
    expect(Coverage::parse-baseline-json('{"path":"a \"quoted\" name"}')<path>)
      .to.eq('a "quoted" name');
  }

  it 'reads the escapes that stand for whitespace', {
    expect(Coverage::parse-baseline-json('{"path":"a\nb\tc\rd"}')<path>).to.eq("a\nb\tc\rd");
  }

  it 'reads an escaped backslash and slash', {
    expect(Coverage::parse-baseline-json('{"path":"a\\\\b\/c"}')<path>).to.eq('a\\b/c');
  }

  it 'reads a list of numbers', {
    expect(Coverage::parse-baseline-json('{"lines":[1,2,3]}')<lines>.elems).to.be(3);
  }

  it 'reads nested objects', {
    expect(Coverage::parse-baseline-json('{"a":{"b":{"c":1}}}')<a><b><c>).to.be(1);
  }

  it 'refuses a list that is not closed', {
    expect({ Coverage::parse-baseline-json('{"lines":[1,2') }).to.throw;
  }

  it 'refuses an object that is not closed', {
    expect({ Coverage::parse-baseline-json('{"a":1') }).to.throw;
  }
}

describe 'reading a source file that carries pod', {
  let(:root, {
    my $dir = $*TMPDIR.add("behave-coverage-pod-{$*PID}-{(now * 1e6).Int.base(36)}");
    $dir.mkdir;
    $dir.add('lib').mkdir;
    $dir.add('lib').add('Documented.rakumod').spurt(q:to/SOURCE/);
    unit module Documented;

    =begin pod

    =head1 Documented

    This prose is not code, and `if True { }` inside it is not a branch.

    =end pod

    our sub answer(--> Int) {
      my $base = 21;
      $base * 2;
    }
    SOURCE
    $dir;
  });

  after-each { remove-tree(root()) }

  let(:source, { root().add('lib').add('Documented.rakumod') });

  it 'leaves the prose out of the executable lines', {
    my $executable = Coverage::identify-executable-lines(source());

    expect($executable.keys.grep({ 5 <= $_ <= 9 }).elems).to.be(0);
  }

  it 'keeps the code after the prose', {
    my $executable = Coverage::identify-executable-lines(source());

    expect($executable.elems > 0).to.be-truthy;
  }

  it 'leaves the prose out of the branching lines', {
    expect(Coverage::identify-branch-lines(source()).keys.grep({ 5 <= $_ <= 9 }).elems).to.be(0);
  }
}

describe 'reading a baseline that is not well formed', {
  it 'refuses an object whose members are not separated', {
    expect({ Coverage::parse-baseline-json('{"a":1 "b":2}') })
      .to.raise-error(/'expected , or }'/);
  }

  it 'refuses a list whose items are not separated', {
    expect({ Coverage::parse-baseline-json('{"a":[1 2]}') })
      .to.raise-error(/'expected , or ]'/);
  }

it 'reads an escape it does not know as the character itself', {
    expect(Coverage::parse-baseline-json(Q[{"path":"a\qb"}])<path>).to.eq('aqb');
  }
}

describe 'comparing a report against a baseline that is missing a file', {
  let(:root, { project() });

  after-each { remove-tree(root()) }

  it 'counts every covered line of the new file as newly covered', {
    my $baseline = root().add('empty-baseline.json');
    $baseline.spurt(Q[{"version":1,"overall":{"percentage":0.0},"files":[]}]);

    my $diff = Coverage::compute-diff(report-of(root()), $baseline);

    expect($diff.newly-covered).to.be(2);
  }
}
