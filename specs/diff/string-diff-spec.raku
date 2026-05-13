use BDD::Behave;
use BDD::Behave::Diff;

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

describe 'string diff', {
  context 'single-line strings', {
    it 'highlights the differing region using common prefix and suffix', {
      my $out = strip-ansi(render-diff('hello world', 'hello earth'));
      expect($out).to.be("- 'hello earth'\n+ 'hello world'");
    }

    it 'shows full strings when nothing in common', {
      my $out = strip-ansi(render-diff('abc', 'xyz'));
      expect($out).to.be("- 'xyz'\n+ 'abc'");
    }

    it 'handles given being a prefix of expected', {
      my $out = strip-ansi(render-diff('abc', 'abcdef'));
      expect($out).to.be("- 'abcdef'\n+ 'abc'");
    }

    it 'handles expected being a prefix of given', {
      my $out = strip-ansi(render-diff('abcdef', 'abc'));
      expect($out).to.be("- 'abc'\n+ 'abcdef'");
    }

    it 'wraps the differing chars with ANSI red for expected', {
      my $out = render-diff('hello world', 'hello earth');
      expect($out.contains("\e[31m")).to.be-truthy;
    }

    it 'wraps the differing chars with ANSI green for given', {
      my $out = render-diff('hello world', 'hello earth');
      expect($out.contains("\e[32m")).to.be-truthy;
    }
  }

  context 'multi-line strings', {
    it 'produces a unified-style line diff', {
      my $given    = "foo\nbar\nbaz";
      my $expected = "foo\nQUX\nbaz";
      my $out      = strip-ansi(render-diff($given, $expected));
      expect($out).to.be("  foo\n- QUX\n+ bar\n  baz");
    }

    it 'shows added lines with a green plus', {
      my $given    = "alpha\nbeta\ngamma";
      my $expected = "alpha\ngamma";
      my $out      = strip-ansi(render-diff($given, $expected));
      expect($out).to.be("  alpha\n+ beta\n  gamma");
    }

    it 'shows removed lines with a red minus', {
      my $given    = "alpha\ngamma";
      my $expected = "alpha\nbeta\ngamma";
      my $out      = strip-ansi(render-diff($given, $expected));
      expect($out).to.be("  alpha\n- beta\n  gamma");
    }
  }
}
