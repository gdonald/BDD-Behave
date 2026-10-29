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

describe 'a discovery subprocess that stops while loading a spec file', {
  let(:errors, {
    discovery-with(
      ('raku', '-e', 'note "behave-loading: /abs/spec.raku"; $*ERR.flush; sleep 30'),
      :timeout(1),
    )[1];
  });

  it 'names the spec file it was loading', {
    expect(errors()[0]<message>).to.include('while loading /abs/spec.raku');
  }
}

describe 'a discovery subprocess that exits with an error after loading a spec file', {
  let(:errors, {
    discovery-with(('raku', '-e', 'note "behave-loading: /abs/spec.raku"; note "load failed"; exit 2'))[1];
  });

  it 'leaves the load progress lines out of the stderr it passes on', {
    expect(errors()[0]<message>).not.to.include('behave-loading');
  }
}

describe 'a discovery subprocess given a progress callable', {
  let(:printed, {
    my @lines;
    discovery-with(
      ('raku', '-e', 'note "behave-loading: /abs/spec.raku"; say "\{\}"'),
      :progress(-> $text, :$partial { @lines.push: $text }),
      :clock({ 0 }),
    );
    @lines.join;
  });

  it 'prints a numbered and timed line for each spec file as it loads', {
    expect(printed()).to.eq('  [1/1] /abs/spec.raku (0.0s)');
  }
}

describe 'discovering no spec files at all', {
  it 'reports nothing and asks nothing of a subprocess', {
    expect(discover-suites-subprocess(())[1].elems).to.be(0);
  }
}
