unit module BDD::Behave::Parallel::Distribution;

need BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

class Bucket {
  has Str $.id is required;
  has Str $.file is required;
  has @.examples;
  has Bool $.serial is rw = False;

  method cost(--> Int) { @!examples.elems }

  method locations(--> List) {
    @!examples.map({ "{$_.file.absolute}:{$_.line}" }).List;
  }

  method add(Example $example) {
    @!examples.push($example);
  }
}

sub effective-serial($node --> Bool) is export {
  my $value = $node.effective-metadata-value('serial');
  ?$value;
}

sub allow-split($group --> Bool) is export {
  ?$group.effective-metadata-value('parallel-split');
}

sub collect-buckets(Suite $suite --> List) is export {
  my @buckets;
  my $prefix = "{$suite.file.absolute}#";
  visit-children($suite, @buckets, $prefix, 0);
  @buckets.List;
}

sub visit-children($container, @buckets, Str $prefix, Int $depth) {
  for $container.children -> $child {
    given $child {
      when Example {
        my $bucket = Bucket.new(
          :id($prefix ~ "ex:{$child.line}"),
          :file($child.file.absolute),
        );
        $bucket.add($child);
        $bucket.serial = effective-serial($child);
        @buckets.push($bucket);
      }
      when ExampleGroup {
        if allow-split($child) {
          visit-children($child, @buckets, $prefix ~ "g{$depth}:{$child.line}/", $depth + 1);
        } else {
          my $bucket = Bucket.new(
            :id($prefix ~ "g{$depth}:{$child.line}"),
            :file($child.file.absolute),
          );
          collect-examples($child, $bucket);
          $bucket.serial = group-has-only-serial($bucket);
          @buckets.push($bucket);
        }
      }
    }
  }
}

sub collect-examples($node, Bucket $bucket) {
  given $node {
    when Example {
      $bucket.add($node);
    }
    when ExampleGroup | Suite {
      for $node.children -> $child {
        collect-examples($child, $bucket);
      }
    }
  }
}

sub group-has-only-serial(Bucket $bucket --> Bool) {
  return False unless $bucket.examples.elems;
  for $bucket.examples -> $ex {
    return False unless effective-serial($ex);
  }
  True;
}

sub coalesce-by-file(@buckets --> List) is export {
  my %by-file;
  my @order;

  for @buckets -> $b {
    unless %by-file{$b.file}:exists {
      %by-file{$b.file} = Bucket.new(:id($b.file), :file($b.file));
      @order.push: $b.file;
    }

    %by-file{$b.file}.add($_) for $b.examples;
  }

  @order.map({ %by-file{$_} }).List;
}

sub split-parallel-and-serial(@buckets --> List) is export {
  my @parallel;
  my @serial;
  for @buckets -> $b {
    if $b.serial {
      @serial.push($b);
    } else {
      my @serial-examples;
      my @parallel-examples;
      for $b.examples -> $ex {
        if effective-serial($ex) {
          @serial-examples.push($ex);
        } else {
          @parallel-examples.push($ex);
        }
      }
      if @parallel-examples.elems {
        my $par-bucket = Bucket.new(:id($b.id), :file($b.file));
        $par-bucket.add($_) for @parallel-examples;
        @parallel.push($par-bucket);
      }
      if @serial-examples.elems {
        my $ser-bucket = Bucket.new(:id($b.id ~ '#serial'), :file($b.file));
        $ser-bucket.add($_) for @serial-examples;
        $ser-bucket.serial = True;
        @serial.push($ser-bucket);
      }
    }
  }
  (@parallel.List, @serial.List).List;
}

sub distribute-lpt(@buckets, Int $worker-count --> List) is export {
  die "worker-count must be a positive integer (got: $worker-count)"
    if $worker-count < 1;

  my @assignments;
  @assignments.push([]) for ^$worker-count;
  my @loads = (0 xx $worker-count).Array;

  my @sorted = @buckets.sort({ $^b.cost <=> $^a.cost });
  for @sorted -> $b {
    my $min-idx = 0;
    for 1 ..^ $worker-count -> $i {
      $min-idx = $i if @loads[$i] < @loads[$min-idx];
    }
    @assignments[$min-idx].push($b);
    @loads[$min-idx] += $b.cost;
  }

  @assignments.map(*.List).List;
}

sub fnv1a-hash(Str $s --> Int) {
  my $h = 0x811c9dc5;
  for $s.encode('utf-8').list -> $byte {
    $h = (($h +^ $byte) * 0x01000193) +& 0xFFFFFFFF;
  }
  $h;
}

sub bucket-stable-key(Bucket $b, Int $seed --> Int) is export {
  my $h = fnv1a-hash($b.id);

  my $s = $seed.abs +& 0xFFFFFFFF;

  for ^4 -> $i {
    my $byte = ($s +> (8 * $i)) +& 0xFF;
    $h = (($h +^ $byte) * 0x01000193) +& 0xFFFFFFFF;
  }

  $h;
}

sub distribute-stable(@buckets, Int $worker-count, Int $seed --> List) is export {
  die "worker-count must be a positive integer (got: $worker-count)"
    if $worker-count < 1;

  my @sorted = @buckets.sort({
       bucket-stable-key($^a, $seed) <=> bucket-stable-key($^b, $seed)
    || $^a.id leg $^b.id
  });

  my @assignments;
  @assignments.push([]) for ^$worker-count;

  for @sorted.kv -> $idx, $b {
    @assignments[$idx % $worker-count].push($b);
  }

  @assignments.map(*.List).List;
}
