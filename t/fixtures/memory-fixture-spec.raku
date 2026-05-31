use BDD::Behave;

sub resident-buffer(Int $bytes) {
  my $buf = Buf.allocate($bytes, 0);

  loop (my int $offset = 0; $offset < $bytes; $offset = $offset + 4096) {
    $buf[$offset] = 1;
  }

  $buf;
}

describe 'memory-fixture', :order<defined>, {
  it 'a allocates a chunk', {
    my $buf = resident-buffer(16 * 1024 * 1024);
    expect($buf.elems).to.be(16 * 1024 * 1024);
  }

  it 'b allocates a bigger chunk', {
    my $buf = resident-buffer(32 * 1024 * 1024);
    expect($buf.elems).to.be(32 * 1024 * 1024);
  }

  it 'c small example', {
    expect(1 + 1).to.be(2);
  }
}
