use BDD::Behave;
use BDD::Behave::Parallel::Queue;
use BDD::Behave::Parallel::Distribution;
use BDD::Behave::SpecTree;

constant Example = BDD::Behave::SpecTree::Example;
constant Bucket  = BDD::Behave::Parallel::Distribution::Bucket;

sub mk-bucket(Str $id, Int $count = 1, Str $file = '/abs/spec.raku') {
  my $b = Bucket.new(:$id, :$file);
  for ^$count {
    $b.add(Example.new(:description("ex$_"), :file($file.IO), :line(10 + $_), :block(sub { })));
  }
  $b;
}

describe 'QueueScheduler', {
  it 'starts empty', {
    my $s = QueueScheduler.new;

    expect($s.has-pending).to.be-falsy;
    expect($s.pending-count).to.be(0);
  }

  it 'enqueues a single bucket', {
    my $s = QueueScheduler.new;
    $s.enqueue(mk-bucket('b1'));

    expect($s.pending-count).to.be(1);
    expect($s.has-pending).to.be-truthy;
  }

  it 'pops buckets in FIFO order with enqueue', {
    my $s = QueueScheduler.new;
    $s.enqueue(mk-bucket('a'));
    $s.enqueue(mk-bucket('b'));
    $s.enqueue(mk-bucket('c'));

    expect($s.next-bucket.id).to.be('a');
    expect($s.next-bucket.id).to.be('b');
    expect($s.next-bucket.id).to.be('c');
  }

  it 'sorts by cost descending with enqueue-sorted', {
    my $s = QueueScheduler.new;
    my @buckets = (
      mk-bucket('small', 1),
      mk-bucket('large', 5),
      mk-bucket('medium', 3),
    );
    $s.enqueue-sorted(@buckets);

    expect($s.next-bucket.id).to.be('large');
    expect($s.next-bucket.id).to.be('medium');
    expect($s.next-bucket.id).to.be('small');
  }

  it 'returns an undefined Bucket when empty', {
    my $s = QueueScheduler.new;

    expect($s.next-bucket.defined).to.be-falsy;
  }

  it 'tracks dispatched and completed counts', {
    my $s = QueueScheduler.new;
    $s.enqueue(mk-bucket('a'));
    $s.enqueue(mk-bucket('b'));

    $s.next-bucket;

    expect($s.dispatched).to.be(1);
    expect($s.completed).to.be(0);

    $s.mark-complete;
    $s.next-bucket;
    $s.mark-complete;

    expect($s.dispatched).to.be(2);
    expect($s.completed).to.be(2);
  }

  it 'reports all-complete only after every dispatched bucket is acked', {
    my $s = QueueScheduler.new;
    $s.enqueue(mk-bucket('a'));
    $s.next-bucket;

    expect($s.all-complete).to.be-falsy;

    $s.mark-complete;

    expect($s.all-complete).to.be-truthy;
  }
}

describe 'format-bucket-command', {
  it 'serializes a single-example bucket', {
    my $b = mk-bucket('id-1', 1, '/abs/foo.raku');
    my $cmd = format-bucket-command($b);

    expect($cmd).to.match(/^ 'BUCKET' \t 'id-1' \t /);
    expect($cmd).to.match(/'/abs/foo.raku' \t /);
    expect($cmd).to.match(/':10' $/);
  }

  it 'joins multiple example locations with commas', {
    my $b = mk-bucket('id-2', 3, '/abs/bar.raku');
    my $cmd = format-bucket-command($b);

    expect($cmd).to.include('10,/abs/bar.raku:11,/abs/bar.raku:12');
  }

  it 'contains no embedded newlines', {
    my $b = mk-bucket('id-3', 2);
    my $cmd = format-bucket-command($b);

    expect($cmd.contains("\n")).to.be-falsy;
  }
}

describe 'parse-bucket-command', {
  it 'recognizes SHUTDOWN', {
    my %r = parse-bucket-command("SHUTDOWN");

    expect(%r<type>).to.be('shutdown');
  }

  it 'tolerates a trailing newline on SHUTDOWN', {
    my %r = parse-bucket-command("SHUTDOWN\n");

    expect(%r<type>).to.be('shutdown');
  }

  it 'returns unknown for empty input', {
    my %r = parse-bucket-command('');

    expect(%r<type>).to.be('unknown');
  }

  it 'returns unknown for malformed lines', {
    my %r = parse-bucket-command("garbage line");

    expect(%r<type>).to.be('unknown');
  }

  it 'returns unknown for a BUCKET line with too few fields', {
    my %r = parse-bucket-command("BUCKET\tid-only");

    expect(%r<type>).to.be('unknown');
  }

  it 'parses a BUCKET line with one location', {
    my %r = parse-bucket-command("BUCKET\tbucket-1\t/abs/x.raku\t/abs/x.raku:10");

    expect(%r<type>).to.be('bucket');
    expect(%r<id>).to.be('bucket-1');
    expect(%r<file>).to.be('/abs/x.raku');
    expect(%r<locations>.elems).to.be(1);
    expect(%r<locations>[0]).to.be('/abs/x.raku:10');
  }

  it 'parses a BUCKET line with multiple locations', {
    my %r = parse-bucket-command("BUCKET\tbucket-2\t/abs/y.raku\t/abs/y.raku:10,/abs/y.raku:20,/abs/y.raku:30");

    expect(%r<locations>.elems).to.be(3);
    expect(%r<locations>[0]).to.be('/abs/y.raku:10');
    expect(%r<locations>[1]).to.be('/abs/y.raku:20');
    expect(%r<locations>[2]).to.be('/abs/y.raku:30');
  }

  it 'round-trips with format-bucket-command', {
    my $b = mk-bucket('rt-1', 4, '/abs/round.raku');
    my $cmd = format-bucket-command($b);

    my %r = parse-bucket-command($cmd);

    expect(%r<type>).to.be('bucket');
    expect(%r<id>).to.be('rt-1');
    expect(%r<file>).to.be('/abs/round.raku');
    expect(%r<locations>.elems).to.be(4);
  }
}

sub run-behave(@argv --> Hash) {
  my @cmd = 'raku', '-Ilib', 'bin/behave', |@argv;
  my $proc = run(|@cmd, :out, :err, :cwd($*CWD));
  my $stdout = $proc.out.slurp(:close);
  my $stderr = $proc.err.slurp(:close);
  %( :exitcode($proc.exitcode), :$stdout, :$stderr );
}

describe '`behave --parallel-mode=queue` end-to-end', {
  it 'rejects an unknown --parallel-mode', {
    my %r = run-behave(['--parallel-mode=bogus', '--no-config',
                        't/fixtures/parallel/queue-a-spec.raku']);

    expect(%r<exitcode>).to.be(2);
    expect(%r<stderr>).to.include('--parallel-mode');
  }

  it 'runs every parallel example in the suite', {
    my %r = run-behave(['--parallel', '2', '--parallel-mode=queue', '--no-config',
                        't/fixtures/parallel/queue-a-spec.raku',
                        't/fixtures/parallel/queue-b-spec.raku',
                        't/fixtures/parallel/queue-c-spec.raku']);

    expect(%r<stdout>).to.match(/'Overall: 7 examples'/);
  }

  it 'reports the failure from the b-spec fixture', {
    my %r = run-behave(['--parallel', '2', '--parallel-mode=queue', '--no-config',
                        't/fixtures/parallel/queue-a-spec.raku',
                        't/fixtures/parallel/queue-b-spec.raku',
                        't/fixtures/parallel/queue-c-spec.raku']);

    expect(%r<stdout>).to.match(/'1 failed'/);
    expect(%r<exitcode>).to.be(1);
  }

  it 'produces the same pass/fail counts as --parallel-mode=lpt', {
    my @args = ('--parallel', '2', '--no-config', '--order', 'defined',
                't/fixtures/parallel/queue-a-spec.raku',
                't/fixtures/parallel/queue-b-spec.raku',
                't/fixtures/parallel/queue-c-spec.raku');
    my %lpt   = run-behave(['--parallel-mode=lpt',   |@args]);
    my %queue = run-behave(['--parallel-mode=queue', |@args]);

    my $lpt-overall   = ~( %lpt<stdout>   ~~ / 'Overall: ' (\d+) ' examples' / );
    my $queue-overall = ~( %queue<stdout> ~~ / 'Overall: ' (\d+) ' examples' / );

    expect($lpt-overall).to.be($queue-overall);
    expect(%lpt<exitcode>).to.be(%queue<exitcode>);
  }

  it 'works with --parallel 1 (single worker pulls every bucket)', {
    my %r = run-behave(['--parallel', '1', '--parallel-mode=queue', '--no-config',
                        't/fixtures/parallel/queue-a-spec.raku']);

    expect(%r<stdout>).to.match(/'2 examples'/);
    expect(%r<exitcode>).to.be(0);
  }

  it 'tolerates a tag filter that matches no examples', {
    my %r = run-behave(['--parallel', '2', '--parallel-mode=queue', '--no-config',
                        '--tag', 'no-such-tag',
                        't/fixtures/parallel/queue-a-spec.raku',
                        't/fixtures/parallel/queue-b-spec.raku']);

    expect(%r<stdout>).to.match(/'Overall: 0 examples'/);
    expect(%r<exitcode>).to.be(0);
  }

  it 'still runs the serial-tagged example from queue-c-spec', {
    my %r = run-behave(['--parallel', '2', '--parallel-mode=queue', '--no-config',
                        '-e', 'queue fixture C',
                        't/fixtures/parallel/queue-c-spec.raku']);

    expect(%r<stdout>).to.match(/'2 examples'/);
    expect(%r<stdout>).to.match(/'2 passed'/);
  }
}
