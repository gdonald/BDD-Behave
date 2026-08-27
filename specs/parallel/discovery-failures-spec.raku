use BDD::Behave;
use BDD::Behave::Parallel;

# Discovery runs behave in a subprocess and reads a JSON document back. The
# argv is a parameter, so each way that subprocess can let the parent down is
# driven here by standing a small raku program in its place.
sub discovery-with(@argv, *%named --> List) {
  discover-suites-subprocess(
    ('/abs/spec.raku',),
    :discovery-argv(@argv),
    :base-env(%(|%*ENV, BEHAVE_DISABLE_CONFIG => '1')),
    |%named,
  );
}

describe 'a discovery subprocess that writes something other than json', {
  let(:errors, {
    discovery-with(('raku', '-e', 'say "not json at all"'))[1];
  });

  it 'reports one error per spec file', {
    expect(errors().elems).to.be(1);
  }

  it 'names the file it was discovering', {
    expect(errors()[0]<file>).to.eq('/abs/spec.raku');
  }

  it 'says the document could not be read', {
    expect(errors()[0]<message>).to.include('returned invalid JSON');
  }
}

describe 'a discovery subprocess that exits with an error', {
  let(:errors, {
    discovery-with(('raku', '-e', 'note "load failed"; exit 2'))[1];
  });

  it 'reports one error per spec file', {
    expect(errors().elems).to.be(1);
  }

  it 'reports the code it exited with', {
    expect(errors()[0]<message>).to.include('exited with code 2');
  }

  it 'passes on what the subprocess wrote to stderr', {
    expect(errors()[0]<message>).to.include('load failed');
  }
}

describe 'a discovery subprocess that never finishes', {
  let(:errors, {
    discovery-with(('raku', '-e', 'sleep 30'), :timeout(1))[1];
  });

  it 'reports one error per spec file', {
    expect(errors().elems).to.be(1);
  }

  it 'says how long it waited', {
    expect(errors()[0]<message>).to.include('timed out after 1s');
  }

  it 'suggests what usually causes it', {
    expect(errors()[0]<message>).to.include('stale precompilation');
  }
}

describe 'discovering no spec files at all', {
  it 'reports nothing and asks nothing of a subprocess', {
    expect(discover-suites-subprocess(())[1].elems).to.be(0);
  }
}
