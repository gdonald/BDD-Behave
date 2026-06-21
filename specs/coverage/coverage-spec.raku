use BDD::Behave;
use BDD::Behave::Coverage;

constant Coverage        = BDD::Behave::Coverage;
constant CoverageOptions = BDD::Behave::Coverage::CoverageOptions;
constant FileCoverage    = BDD::Behave::Coverage::FileCoverage;
constant CoverageReport  = BDD::Behave::Coverage::CoverageReport;

sub tmp-source(Str $body --> IO::Path) {
  my $dir = $*TMPDIR.add("behave-cov-{$*PID}-{(now * 1e6).Int}");
  $dir.mkdir;
  my $p = $dir.add('SampleSource.rakumod');
  $p.spurt($body);
  $p;
}

sub cleanup-tmp-source(IO::Path $p) {
  $p.unlink if $p.e;
  $p.parent.rmdir if $p.parent.e && !$p.parent.dir.elems;
}

sub tmp-log(Str $body --> IO::Path) {
  my $p = $*TMPDIR.add("behave-cov-log-{$*PID}-{(now * 1e6).Int}.log");
  $p.spurt($body);
  $p;
}

describe 'BDD::Behave::Coverage::CoverageOptions', {
  it 'defaults to disabled with 0 minimum and text format', {
    my $o = CoverageOptions.new;
    expect($o.enabled).to.be-falsy;
    expect($o.minimum).to.be(0);
    expect($o.format).to.eq('text');
    expect($o.branch).to.be-falsy;
  }

  it 'supports include-path repeatable accumulation', {
    my $o = CoverageOptions.new;
    $o.include-path('lib/Foo');
    $o.include-path('lib/Bar');
    expect($o.include-paths.elems).to.be(2);
    expect($o.include-paths[0]).to.eq('lib/Foo');
    expect($o.include-paths[1]).to.eq('lib/Bar');
  }

  it 'supports exclude-path repeatable accumulation', {
    my $o = CoverageOptions.new;
    $o.exclude-path('lib/vendor');
    expect($o.exclude-paths.elems).to.be(1);
    expect($o.exclude-paths[0]).to.eq('lib/vendor');
  }
}

describe 'BDD::Behave::Coverage::matches-path-filter', {
  it 'returns true with no include and no exclude', {
    expect(?Coverage::matches-path-filter('lib/foo.rakumod', (), ())).to.be-truthy;
  }

  it 'returns true when file contains an include pattern', {
    expect(?Coverage::matches-path-filter('lib/foo.rakumod', ('lib/',), ())).to.be-truthy;
  }

  it 'returns false when no include pattern matches', {
    expect(?Coverage::matches-path-filter('app/foo.raku', ('lib/',), ())).to.be-falsy;
  }

  it 'returns false when an exclude pattern matches', {
    expect(?Coverage::matches-path-filter('lib/vendor/foo.rakumod', (), ('vendor/',))).to.be-falsy;
  }

  it 'exclude wins over include when both match', {
    expect(?Coverage::matches-path-filter('lib/vendor/foo.rakumod', ('lib/',), ('vendor/',))).to.be-falsy;
  }

  it 'treats include as a path prefix, not a substring', {
    expect(?Coverage::matches-path-filter(
      '/Users/gd/rakudo/share/nqp/lib/MAST/Ops.nqp',
      ('lib/',), (),
    )).to.be-falsy;
  }
}

describe 'BDD::Behave::Coverage::identify-executable-lines', {
  it 'skips blank lines and comments', {
    my $body = join("\n",
      '# a top comment',
      'sub foo() {',
      '  my $x = 1;',
      '',
      '  # mid comment',
      '  $x + 1;',
      '}',
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-executable-lines($f);
    cleanup-tmp-source($f);
    expect($set.elems).to.be-greater-than(0);
    expect(?$set{1}).to.be-falsy;
    expect(?$set{2}).to.be-truthy;
    expect(?$set{3}).to.be-truthy;
    expect(?$set{4}).to.be-falsy;
    expect(?$set{5}).to.be-falsy;
    expect(?$set{6}).to.be-truthy;
  }

  it 'returns an empty set for a non-existent file', {
    my $set = Coverage::identify-executable-lines('/does/not/exist.rakumod'.IO);
    expect($set.elems).to.be(0);
  }

  it 'skips continuation lines inside a multi-line ( ... ) expression', {
    my $body = join("\n",
      'method ex-record($e) {',                  # 1: executable
      '  my %record = (',                        # 2: executable
      '    description => $e.desc,',             # 3: continuation, skip
      '    file        => $e.file,',             # 4: continuation, skip
      '    line        => $e.line,',             # 5: continuation, skip
      '  );',                                    # 6: closing brace/paren, skip
      '  %record;',                              # 7: executable
      '}',                                       # 8: skip
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-executable-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{1}).to.be-truthy;
    expect(?$set{2}).to.be-truthy;
    expect(?$set{3}).to.be-falsy;
    expect(?$set{4}).to.be-falsy;
    expect(?$set{5}).to.be-falsy;
    expect(?$set{6}).to.be-falsy;
    # %record; is a bare-value implicit return — MoarVM doesn't HIT it.
    expect(?$set{7}).to.be-falsy;
    expect(?$set{8}).to.be-falsy;
  }

  it 'counts statements inside a lambda body passed to .map(...)', {
    my $body = join("\n",
      'method foo($items) {',                  # 1: executable
      '  $items.map(-> $x {',                  # 2: executable, lambda opens
      '    my %r = (',                         # 3: executable (inside { })
      '      a => $x.a,',                      # 4: continuation, skip
      '      b => $x.b,',                      # 5: continuation, skip
      '    );',                                # 6: skip (closing paren)
      '    %r;',                               # 7: executable (inside { })
      '  });',                                 # 8: skip (closing brace+paren)
      '}',                                     # 9: skip
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-executable-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{1}).to.be-truthy;
    expect(?$set{2}).to.be-truthy;
    expect(?$set{3}).to.be-truthy;
    expect(?$set{4}).to.be-falsy;
    expect(?$set{5}).to.be-falsy;
    expect(?$set{6}).to.be-falsy;
    # %r; is a bare-value implicit return — MoarVM doesn't HIT it.
    expect(?$set{7}).to.be-falsy;
  }

  it 'still counts statements inside a multi-line { ... } block', {
    my $body = join("\n",
      'method foo() {',
      '  if 1 {',
      '    say "hi";',
      '    say "ok";',
      '  }',
      '}',
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-executable-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{2}).to.be-truthy;
    expect(?$set{3}).to.be-truthy;
    expect(?$set{4}).to.be-truthy;
  }

  it 'skips closing-continuation and bare-value lines', {
    my $body = join("\n",
      'method foo() {',
      '  my %rec = compute();',           # 2: executable
      '  %rec<flag> = True;',              # 3: executable (assignment)
      '  %rec;',                           # 4: bare value, skip
      '}',                                 # 5: closing, skip
      '',
      'method bar() {',
      '  $items.map(-> $x {',              # 8: executable
      '    $x + 1;',                       # 9: executable
      '  }).List;',                        # 10: closing-continuation, skip
      '}',                                 # 11: skip
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-executable-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{2}).to.be-truthy;
    expect(?$set{3}).to.be-truthy;
    expect(?$set{4}).to.be-falsy;
    expect(?$set{5}).to.be-falsy;
    expect(?$set{9}).to.be-truthy;
    expect(?$set{10}).to.be-falsy;
  }

  it 'skips pure my/our/state declarations with no initializer', {
    my $body = join("\n",
      'method foo() {',                # 1: executable
      '  my @parts;',                  # 2: skip (pure decl)
      '  my $count;',                  # 3: skip
      '  my (@a, @b);',                # 4: skip
      '  state $hit;',                 # 5: skip
      '  my $x = 0;',                  # 6: executable (has assignment)
      '  my $y := $x;',                # 7: executable (bind)
      '  @parts.push: 1;',             # 8: executable
      '}',                             # 9: skip (close)
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-executable-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{1}).to.be-truthy;
    expect(?$set{2}).to.be-falsy;
    expect(?$set{3}).to.be-falsy;
    expect(?$set{4}).to.be-falsy;
    expect(?$set{5}).to.be-falsy;
    expect(?$set{6}).to.be-truthy;
    expect(?$set{7}).to.be-truthy;
    expect(?$set{8}).to.be-truthy;
  }

  it 'skips declarative lines MoarVM does not emit HITs for', {
    my $body = join("\n",
      'use Foo;',                # 1: skip
      'need Bar;',               # 2: skip
      'unit class X;',           # 3: skip
      'has @!items;',            # 4: skip
      'constant TAU = 6.28;',    # 5: skip
      'subset Even of Int;',     # 6: skip
      'my class Inner { }',      # 7: skip
      'method foo() {',          # 8: executable
      '  @!items.push: 1;',      # 9: executable
      '}',                       # 10: closing brace, skip
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-executable-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{1}).to.be-falsy;
    expect(?$set{2}).to.be-falsy;
    expect(?$set{3}).to.be-falsy;
    expect(?$set{4}).to.be-falsy;
    expect(?$set{5}).to.be-falsy;
    expect(?$set{6}).to.be-falsy;
    expect(?$set{7}).to.be-falsy;
    expect(?$set{8}).to.be-truthy;
    expect(?$set{9}).to.be-truthy;
    expect(?$set{10}).to.be-falsy;
  }

  it 'excludes lines between a pair of nocov markers', {
    my $body = join("\n",
      'sub foo() {',                 # 1: executable
      '  my $x = 1;',                # 2: executable
      '  # :nocov:',                 # 3: marker
      '  my $unreachable = 2;',      # 4: excluded
      '  warn $unreachable;',        # 5: excluded
      '  # :nocov:',                 # 6: marker
      '  $x + 1;',                   # 7: executable
      '}',
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-executable-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{2}).to.be-truthy;
    expect(?$set{4}).to.be-falsy;
    expect(?$set{5}).to.be-falsy;
    expect(?$set{7}).to.be-truthy;
  }

  it 'excludes through end of file when a nocov opener has no closer', {
    my $body = join("\n",
      'sub foo() {',                 # 1: executable
      '  my $x = 1;',                # 2: executable
      '  # :nocov:',                 # 3: marker
      '  my $y = 2;',                # 4: excluded
      '  $y + 1;',                   # 5: excluded
      '}',                           # 6: excluded
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-executable-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{2}).to.be-truthy;
    expect(?$set{4}).to.be-falsy;
    expect(?$set{5}).to.be-falsy;
  }
}

describe 'BDD::Behave::Coverage::is-nocov-marker', {
  it 'recognizes a bare marker comment regardless of spacing', {
    expect(Coverage::is-nocov-marker('# :nocov:')).to.be-truthy;
  }

  it 'recognizes a marker with no space after the hash', {
    expect(Coverage::is-nocov-marker('#:nocov:')).to.be-truthy;
  }

  it 'does not treat a line with trailing code as a marker', {
    expect(Coverage::is-nocov-marker('# :nocov: and more')).to.be-falsy;
  }

  it 'does not treat an ordinary comment as a marker', {
    expect(Coverage::is-nocov-marker('# a normal comment')).to.be-falsy;
  }
}

describe 'BDD::Behave::Coverage::identify-branch-lines', {
  it 'flags if/unless/given/when/while lines', {
    my $body = join("\n",
      'sub foo($x) {',
      '  if $x > 0 { say "pos" }',
      '  unless $x { say "zero" }',
      '  given $x {',
      '    when 1 { say "one" }',
      '    default { say "other" }',
      '  }',
      '  while $x-- { }',
      '}',
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-branch-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{2}).to.be-truthy;
    expect(?$set{3}).to.be-truthy;
    expect(?$set{4}).to.be-truthy;
    expect(?$set{5}).to.be-truthy;
    expect(?$set{8}).to.be-truthy;
  }

  it 'does not flag a branch line inside a nocov block', {
    my $body = join("\n",
      'sub foo($x) {',
      '  # :nocov:',
      '  if $x > 0 { say "pos" }',
      '  # :nocov:',
      '}',
    );
    my $f = tmp-source($body);
    my $set = Coverage::identify-branch-lines($f);
    cleanup-tmp-source($f);
    expect(?$set{3}).to.be-falsy;
  }
}

describe 'BDD::Behave::Coverage::process-hit-line', {
  it 'records the file and line for a HIT log entry', {
    my %hits;
    Coverage::process-hit-line(
      'HIT  /path/to/file.rakumod  42',
      %hits, :include-paths(()), :exclude-paths(()),
    );
    expect(%hits</path/to/file.rakumod>:exists).to.be-truthy;
    expect(?%hits</path/to/file.rakumod>{42}).to.be-truthy;
  }

  it 'strips a trailing (ModuleName) suffix', {
    my %hits;
    Coverage::process-hit-line(
      'HIT  /path/to/file.rakumod (Foo::Bar)  7',
      %hits, :include-paths(()), :exclude-paths(()),
    );
    expect(?%hits</path/to/file.rakumod>{7}).to.be-truthy;
  }

  it 'ignores lines that do not start with HIT', {
    my %hits;
    Coverage::process-hit-line(
      'SOMETHING ELSE  /x  9',
      %hits, :include-paths(()), :exclude-paths(()),
    );
    expect(%hits.elems).to.be(0);
  }

  it 'skips lines that do not match the include filter', {
    my %hits;
    Coverage::process-hit-line(
      'HIT  /elsewhere/foo.rakumod  3',
      %hits, :include-paths(('lib/',)), :exclude-paths(()),
    );
    expect(%hits.elems).to.be(0);
  }

  it 'sums a tab-prefixed occurrence count across repeated lines', {
    my %hits;
    Coverage::process-hit-line(
      "5\tHIT  /path/to/file.rakumod  10",
      %hits, :include-paths(()), :exclude-paths(()),
    );
    Coverage::process-hit-line(
      "3\tHIT  /path/to/file.rakumod  10",
      %hits, :include-paths(()), :exclude-paths(()),
    );
    expect(%hits</path/to/file.rakumod>{10}).to.be(8);
  }
}

describe 'BDD::Behave::Coverage::FileCoverage hit counts', {
  let(:file-cov, {
    my $f = FileCoverage.new(:path('/p'));
    $f.executable{1} = True;
    $f.executable{2} = True;
    $f.add-hit(1, 4);
    $f.add-hit(1, 6);
    $f;
  });

  it 'accumulates added counts for a line', {
    expect(file-cov.hit-count(1)).to.be(10);
  }

  it 'reports zero hits for a line that was never hit', {
    expect(file-cov.hit-count(2)).to.be(0);
  }

  it 'sums counts over covered executable lines as total-hits', {
    expect(file-cov.total-hits).to.be(10);
  }
}

describe 'BDD::Behave::Coverage::merge-coverage-logs', {
  it 'unions hits from multiple raw logs into one map', {
    my $a = tmp-log("HIT  /a.rakumod  1\nHIT  /a.rakumod  2\n");
    my $b = tmp-log("HIT  /a.rakumod  2\nHIT  /a.rakumod  5\nHIT  /b.rakumod  9\n");

    my %hits = Coverage::merge-coverage-logs([$a, $b], :include-paths(()), :exclude-paths(()));

    $a.unlink; $b.unlink;

    expect(%hits.keys.elems).to.be(2);
    expect(?%hits</a.rakumod>{1}).to.be-truthy;
    expect(?%hits</a.rakumod>{2}).to.be-truthy;
    expect(?%hits</a.rakumod>{5}).to.be-truthy;
    expect(?%hits</b.rakumod>{9}).to.be-truthy;
  }

  it 'respects include-paths during the merge', {
    my $a = tmp-log("HIT  /a.rakumod  1\n");
    my $b = tmp-log("HIT  /b.rakumod  9\n");

    my %hits = Coverage::merge-coverage-logs(
      [$a, $b], :include-paths(('/b.',)), :exclude-paths(()),
    );

    $a.unlink; $b.unlink;

    expect(%hits.keys.elems).to.be(1);
    expect(%hits</b.rakumod>:exists).to.be-truthy;
  }

  it 'returns an empty hash when given an empty list', {
    my %hits = Coverage::merge-coverage-logs([], :include-paths(()), :exclude-paths(()));
    expect(%hits.elems).to.be(0);
  }

  it 'silently skips missing log files', {
    my $missing = $*TMPDIR.add("behave-cov-missing-{$*PID}-{(now * 1e6).Int}.log");
    my %hits = Coverage::merge-coverage-logs(
      [$missing], :include-paths(()), :exclude-paths(()),
    );
    expect(%hits.elems).to.be(0);
  }
}

describe 'BDD::Behave::Coverage::parse-coverage-log', {
  it 'parses a multi-line HIT log into a per-file hit set', {
    my $log = tmp-log(qq:to/EOF/);
    HIT  /a.rakumod  1
    HIT  /a.rakumod  2
    HIT  /a.rakumod  2
    HIT  /b.rakumod  9
    not a hit
    EOF
    my %hits = Coverage::parse-coverage-log($log, :include-paths(()), :exclude-paths(()));
    $log.unlink;
    expect(%hits.keys.elems).to.be(2);
    expect(?%hits</a.rakumod>{1}).to.be-truthy;
    expect(?%hits</a.rakumod>{2}).to.be-truthy;
    expect(?%hits</b.rakumod>{9}).to.be-truthy;
  }
}

describe 'BDD::Behave::Coverage::FileCoverage percentage', {
  it 'reports 100% when there are no executable lines', {
    my $fc = FileCoverage.new(:path('/nope'));
    expect($fc.percentage.Int).to.be(100);
  }

  it 'computes percentage from hits over executable', {
    my $fc = FileCoverage.new(:path('/x'));
    $fc.executable{1} = True;
    $fc.executable{2} = True;
    $fc.executable{3} = True;
    $fc.executable{4} = True;
    $fc.add-hit(1);
    $fc.add-hit(2);
    $fc.add-hit(3);
    expect($fc.percentage.Int).to.be(75);
    expect($fc.total-lines).to.be(4);
    expect($fc.covered-lines).to.be(3);
    my @missing = $fc.missing-lines;
    expect(@missing.elems).to.be(1);
    expect(@missing[0]).to.be(4);
  }
}

describe 'BDD::Behave::Coverage::compress-line-ranges', {
  it 'compresses adjacent integers into ranges', {
    expect(Coverage::compress-line-ranges([1, 2, 3, 7, 9, 10])).to.eq('1-3, 7, 9-10');
  }

  it 'returns an empty string for an empty list', {
    expect(Coverage::compress-line-ranges([])).to.eq('');
  }
}

describe 'BDD::Behave::Coverage::build-report-from-hits', {
  it 'builds a per-file report from a hits hash', {
    my $body = join("\n",
      'sub a() {',
      '  my $x = 1;',
      '  $x + 1;',
      '}',
      'sub b() {',
      '  99;',
      '}',
    );
    my $src = tmp-source($body);
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    %hits{$src.Str}{2} = True;
    %hits{$src.Str}{3} = True;
    %hits{$src.Str}{5} = True;

    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    cleanup-tmp-source($src);

    expect($report.files.elems).to.be(1);
    expect($report.files[0].total-lines).to.be-greater-than(0);
    expect($report.overall-percentage).to.be-greater-than(0);
  }

  it 'skips a hits key that resolves to a directory instead of a source file', {
    my $src = tmp-source('sub a() { 1; }');

    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    %hits{$src.parent.Str} = SetHash.new;
    %hits{$src.parent.Str}{1} = True;

    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);

    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    cleanup-tmp-source($src);

    expect($report.files.elems).to.be(1);
  }

  it 'does not count an uncovered line inside a nocov block as missed', {
    my $body = join("\n",
      'sub a() {',         # 1: executable, covered
      '  my $x = 1;',      # 2: executable, covered
      '  # :nocov:',       # 3: marker
      '  warn "bad";',     # 4: excluded, never hit
      '  # :nocov:',       # 5: marker
      '}',
    );
    my $src = tmp-source($body);
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    %hits{$src.Str}{2} = True;

    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    cleanup-tmp-source($src);

    expect($report.overall-percentage).to.be(100e0);
  }
}

describe 'BDD::Behave::Coverage::render-text', {
  it 'includes the file path, covered fraction, and percentage', {
    my $src = tmp-source(join("\n", 'sub foo() {', '  my $x = 1;', '}'));
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    my $text = Coverage::render-text($report, :!color);
    cleanup-tmp-source($src);
    expect($text).to.include('Coverage report');
    expect($text).to.include('Overall:');
  }

  it 'includes a Hits column header', {
    my $src = tmp-source(join("\n", 'sub foo() {', '  my $x = 1;', '}'));
    my %hits;
    %hits{$src.Str}{2} += 7;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    my $text = Coverage::render-text($report, :!color);
    cleanup-tmp-source($src);
    expect($text).to.include('Hits');
  }
}

describe 'BDD::Behave::Coverage::render-json', {
  it 'emits a JSON document with summary and files keys', {
    my $src = tmp-source(q:to/EOF/);
    sub a() { 1; }
    EOF
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    my $json = Coverage::render-json($report);
    cleanup-tmp-source($src);
    expect($json).to.include('"summary"');
    expect($json).to.include('"files"');
    expect($json).to.include('"covered"');
  }

  it 'includes per-file total-hits and per-line line-hits', {
    my $fc = FileCoverage.new(:path('/x'));
    $fc.display-path = 'x';
    $fc.executable{1} = True;
    $fc.add-hit(1, 5);
    my $report = CoverageReport.new(:files([$fc]), :root('/'.IO));
    my $json = Coverage::render-json($report);
    aggregate-failures {
      expect($json).to.include('"total-hits"');
      expect($json).to.include('"line-hits"');
    }
  }

  it 'round-trips through minimal-json-parse', {
    my $src = tmp-source(q:to/EOF/);
    sub a() { 1; }
    EOF
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    my $json = Coverage::render-json($report);
    my %parsed = Coverage::minimal-json-parse($json);
    cleanup-tmp-source($src);
    expect(%parsed<summary>:exists).to.be-truthy;
    expect(%parsed<files>:exists).to.be-truthy;
  }
}

describe 'BDD::Behave::Coverage::format-progress-bar', {
  it 'returns an empty string when the total is unknown', {
    expect(Coverage::format-progress-bar(0, 0, 1e0)).to.eq('');
  }

  context 'partway through the input', {
    let(:bar, { Coverage::format-progress-bar(50, 100, 10e0, :width(24)) });

    it 'shows the percent complete', {
      expect(bar).to.include(' 50%');
    }

    it 'estimates the remaining seconds from elapsed time', {
      expect(bar).to.include('~10s');
    }

    it 'fills the bar proportionally to the fraction done', {
      expect(bar.comb('#').elems).to.be(12);
    }
  }

  context 'once the input is fully processed', {
    let(:bar, { Coverage::format-progress-bar(100, 100, 5e0, :width(24)) });

    it 'reaches one hundred percent', {
      expect(bar).to.include('100%');
    }

    it 'omits the ETA', {
      expect(bar.contains('~')).to.be-falsy;
    }
  }
}

describe 'BDD::Behave::Coverage::render-lcov', {
  it 'emits SF/DA/LF/LH records and end_of_record', {
    my $src = tmp-source(q:to/EOF/);
    sub a() { 1; }
    EOF
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    my $lcov = Coverage::render-lcov($report);
    cleanup-tmp-source($src);
    expect($lcov).to.include('SF:');
    expect($lcov).to.include('DA:');
    expect($lcov).to.include('LF:');
    expect($lcov).to.include('LH:');
    expect($lcov).to.include('end_of_record');
  }

  it 'emits the real hit count in a DA record', {
    my $fc = FileCoverage.new(:path('/x'));
    $fc.executable{1} = True;
    $fc.add-hit(1, 9);
    my $report = CoverageReport.new(:files([$fc]), :root('/'.IO));
    my $lcov = Coverage::render-lcov($report);
    expect($lcov).to.include('DA:1,9');
  }
}

describe 'BDD::Behave::Coverage::render-cobertura', {
  it 'emits a coverage element with line-rate', {
    my $src = tmp-source(q:to/EOF/);
    sub a() { 1; }
    EOF
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    my $xml = Coverage::render-cobertura($report);
    cleanup-tmp-source($src);
    expect($xml).to.include('<?xml');
    expect($xml).to.include('<coverage');
    expect($xml).to.include('line-rate=');
    expect($xml).to.include('</coverage>');
  }
}

describe 'BDD::Behave::Coverage HTML tree', {
  it 'render-html-index emits a summary table page', {
    my $src = tmp-source('sub a() { 1; }');
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    my $html = Coverage::render-html-index($report);
    cleanup-tmp-source($src);
    expect($html).to.include('<!DOCTYPE html>');
    expect($html).to.include('Coverage Report');
    expect($html).to.include('<table id="coverage-table">');
    expect($html).to.include('</html>');
  }

  it 'render-html-file-page emits a single source page without the index table', {
    my $src = tmp-source('sub a() { 1; }');
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);
    my $page = Coverage::render-html-file-page($report.files[0]);
    cleanup-tmp-source($src);
    expect($page).to.include('Back to index');
    expect($page).to.include('<pre class="source">');
    expect($page).to.include('class="src-line');
    expect($page).not.to.include('<thead>');
  }

  it 'write-html-tree creates index.html, style.css, and per-file pages', {
    my $src = tmp-source('sub a() { 1; }');
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);

    my $out-dir = $*TMPDIR.add("behave-cov-tree-{$*PID}-{(now * 1e6).Int}");
    Coverage::write-html-tree($report, $out-dir);

    my $index = $out-dir.add('index.html');
    my $css   = $out-dir.add('style.css');
    expect(?$index.e).to.be-truthy;
    expect(?$css.e).to.be-truthy;

    my $file-page-name = Coverage::file-page-name($report.files[0].display-path);
    expect(?$out-dir.add($file-page-name).e).to.be-truthy;

    for $out-dir.dir -> $f { $f.unlink }
    $out-dir.rmdir;
    cleanup-tmp-source($src);
  }
}

describe 'BDD::Behave::Coverage::valid-format', {
  it 'accepts text, html, json, lcov, cobertura', {
    expect(?Coverage::valid-format('text')).to.be-truthy;
    expect(?Coverage::valid-format('html')).to.be-truthy;
    expect(?Coverage::valid-format('json')).to.be-truthy;
    expect(?Coverage::valid-format('lcov')).to.be-truthy;
    expect(?Coverage::valid-format('cobertura')).to.be-truthy;
  }

  it 'rejects an unknown format', {
    expect(?Coverage::valid-format('xml')).to.be-falsy;
    expect(?Coverage::valid-format('')).to.be-falsy;
  }
}

describe 'BDD::Behave::Coverage::compute-diff', {
  it 'reports zero delta when comparing the same report', {
    my $src = tmp-source(q:to/EOF/);
    sub a() { 1; }
    EOF
    my %hits;
    %hits{$src.Str} = SetHash.new;
    %hits{$src.Str}{1} = True;
    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);
    my $report = Coverage::build-report-from-hits(%hits, $opts, $src.parent);

    my $baseline = $*TMPDIR.add("behave-cov-baseline-{$*PID}-{(now * 1e6).Int}.json");
    $baseline.spurt(Coverage::render-json($report));

    my $diff = Coverage::compute-diff($report, $baseline);
    $baseline.unlink;
    cleanup-tmp-source($src);

    expect($diff.delta.abs).to.be-less-than(0.5);
    expect($diff.newly-covered).to.be(0);
    expect($diff.newly-uncovered).to.be(0);
  }

  it 'detects newly covered lines', {
    my $src = tmp-source(q:to/EOF/);
    sub a() { 1; }
    EOF

    my $opts = CoverageOptions.new;
    $opts.include-path($src.parent.Str);

    my %old-hits;
    %old-hits{$src.Str} = SetHash.new;
    my $old-report = Coverage::build-report-from-hits(%old-hits, $opts, $src.parent);
    my $baseline = $*TMPDIR.add("behave-cov-baseline-{$*PID}-{(now * 1e6).Int}.json");
    $baseline.spurt(Coverage::render-json($old-report));

    my %new-hits;
    %new-hits{$src.Str} = SetHash.new;
    %new-hits{$src.Str}{1} = True;
    my $new-report = Coverage::build-report-from-hits(%new-hits, $opts, $src.parent);

    my $diff = Coverage::compute-diff($new-report, $baseline);
    $baseline.unlink;
    cleanup-tmp-source($src);

    expect($diff.newly-covered).to.be-greater-than(0);
    expect($diff.newly-uncovered).to.be(0);
  }
}

describe 'scrub-managed-coverage-env', {
  my %env;

  before-each {
    %env =
      MVM_COVERAGE_LOG     => '/tmp/inherited.raw',
      MVM_COVERAGE_CONTROL => '1',
      BEHAVE_COVERAGE_LOG  => '/tmp/inherited.raw',
      MVM_COVERAGE_FILES   => 'project/lib',
      PATH                 => '/usr/bin';

    Coverage::scrub-managed-coverage-env(%env);
  }

  it 'removes the inherited MVM_COVERAGE_LOG behave assigns per worker', {
    expect(%env<MVM_COVERAGE_LOG>:exists).to.be-falsy;
  }

  it 'removes the inherited MVM_COVERAGE_CONTROL', {
    expect(%env<MVM_COVERAGE_CONTROL>:exists).to.be-falsy;
  }

  it 'removes the inherited BEHAVE_COVERAGE_LOG', {
    expect(%env<BEHAVE_COVERAGE_LOG>:exists).to.be-falsy;
  }

  it 'leaves a user-supplied MVM_COVERAGE_FILES source filter in place', {
    expect(%env<MVM_COVERAGE_FILES>).to.eq('project/lib');
  }

  it 'leaves unrelated environment variables untouched', {
    expect(%env<PATH>).to.eq('/usr/bin');
  }
}

describe 'remove-coverage-temp', {
  context 'given a dir of per-worker logs', {
    my $dir;

    before-each {
      $dir = $*TMPDIR.add("behave-cov-rm-{$*PID}-{(now * 1e6).Int}");
      $dir.mkdir;
      $dir.add('isolated-0.raw').spurt('HIT  lib/a 1');
      $dir.add('isolated-1.raw').spurt('HIT  lib/b 2');
    }

    it 'reports success', {
      expect(Coverage::remove-coverage-temp($dir)).to.be(True);
    }

    it 'deletes the dir and its logs', {
      Coverage::remove-coverage-temp($dir);
      expect($dir.e).to.be-falsy;
    }
  }

  context 'given a single file', {
    my $file;

    before-each {
      $file = $*TMPDIR.add("behave-cov-rm-{$*PID}-{(now * 1e6).Int}.raw");
      $file.spurt('HIT  lib/a 1');
    }

    it 'deletes the file', {
      Coverage::remove-coverage-temp($file);
      expect($file.e).to.be-falsy;
    }
  }

  context 'given a missing path', {
    it 'is a no-op that reports no removal', {
      expect(Coverage::remove-coverage-temp($*TMPDIR.add("behave-cov-absent-{$*PID}"))).to.be-falsy;
    }
  }
}
