use BDD::Behave;
use BDD::Behave::Failures;

# include / start-with / end-with applied to strings, exercising the
# string types and shapes a user is likely to encounter.

describe 'include matcher with string varieties', {
  describe 'empty strings', {
    it 'matches the empty substring', {
      expect('hello').to.include('');
    }

    it 'matches the empty substring inside the empty string', {
      expect('').to.include('');
    }

    it 'fails to find a non-empty substring inside the empty string', {
      my @captured = capture-failures {
        expect('').to.include('a');
      };
      expect(@captured.elems).to.be(1);
    }
  }

  describe 'whitespace and special characters', {
    it 'matches a substring containing spaces', {
      expect('the quick brown fox').to.include('quick brown');
    }

    it 'matches a tab character', {
      expect("col1\tcol2\tcol3").to.include("\t");
    }

    it 'matches a substring spanning a newline', {
      expect("line1\nline2").to.include("1\nline2");
    }

    it 'matches a substring containing punctuation', {
      expect('error: file not found.').to.include(': ', 'not found');
    }

    it 'distinguishes leading whitespace', {
      my @captured = capture-failures {
        expect('hello').to.include(' hello');
      };
      expect(@captured.elems).to.be(1);
    }
  }

  describe 'multi-line strings', {
    my $haystack = "alpha\nbeta\ngamma\n";

    it 'matches a substring on the first line', {
      expect($haystack).to.include('alpha');
    }

    it 'matches a substring on a middle line', {
      expect($haystack).to.include('beta');
    }

    it 'matches a substring spanning two lines', {
      expect($haystack).to.include("alpha\nbeta");
    }

    it 'matches the trailing newline', {
      expect($haystack).to.include("\n");
    }
  }

  describe 'Unicode strings', {
    it 'matches a multi-byte ASCII-extension substring', {
      expect('café au lait').to.include('café');
    }

    it 'matches a CJK substring', {
      expect('日本語のテスト').to.include('日本');
    }

    it 'matches an emoji substring', {
      expect('done ✅ shipped 🚀').to.include('🚀');
    }

    it 'matches a combining-character grapheme', {
      expect('naïve').to.include('ï');
    }
  }

  describe 'case sensitivity', {
    it 'is case sensitive: lowercase needle in mixed case', {
      my @captured = capture-failures {
        expect('Hello World').to.include('hello');
      };
      expect(@captured.elems).to.be(1);
    }

    it 'is case sensitive: uppercase needle in lowercase haystack', {
      my @captured2 = capture-failures {
        expect('hello world').to.include('WORLD');
      };
      expect(@captured2.elems).to.be(1);
    }

    it 'matches when case matches exactly', {
      expect('Hello World').to.include('Hello', 'World');
    }
  }

  describe 'numeric stringification of needle args', {
    it 'coerces an Int needle to its string form', {
      expect('order #42 confirmed').to.include(42);
    }

    it 'coerces a Rat needle to its string form', {
      expect('pi is about 3.14').to.include(3.14);
    }

    it 'fails when the coerced numeric form is absent', {
      my @captured = capture-failures {
        expect('order #42 confirmed').to.include(99);
      };
      expect(@captured.elems).to.be(1);
    }
  }

  describe 'allomorph and Stringy haystacks', {
    it 'treats an IntStr allomorph as a string', {
      my $allo = <42>;
      expect($allo).to.include('4', '2');
    }

    it 'treats a RatStr allomorph as a string', {
      my $allo = <3.14>;
      expect($allo).to.include('.14');
    }
  }
}

describe 'start-with matcher with string varieties', {
  describe 'empty strings', {
    it 'matches the empty prefix on a non-empty string', {
      expect('hello').to.start-with('');
    }

    it 'matches the empty prefix on the empty string', {
      expect('').to.start-with('');
    }

    it 'fails to find a non-empty prefix on the empty string', {
      my @captured = capture-failures {
        expect('').to.start-with('a');
      };
      expect(@captured.elems).to.be(1);
    }
  }

  describe 'whitespace and special characters', {
    it 'matches a leading space', {
      expect(' indented').to.start-with(' ');
    }

    it 'matches a leading tab', {
      expect("\thello").to.start-with("\t");
    }

    it 'matches a leading newline', {
      expect("\nfirst").to.start-with("\n");
    }

    it 'matches a prefix containing punctuation', {
      expect('-- a comment').to.start-with('-- ');
    }

    it 'distinguishes leading whitespace', {
      my @captured = capture-failures {
        expect('hello').to.start-with(' hello');
      };
      expect(@captured.elems).to.be(1);
    }
  }

  describe 'multi-line strings', {
    my $text = "first line\nsecond line";

    it 'matches a prefix on the first line', {
      expect($text).to.start-with('first');
    }

    it 'matches a prefix that spans into the second line', {
      expect($text).to.start-with("first line\nsecond");
    }

    it 'fails when the prefix lives on the second line', {
      my @captured = capture-failures {
        expect($text).to.start-with('second');
      };
      expect(@captured.elems).to.be(1);
    }
  }

  describe 'Unicode strings', {
    it 'matches a multi-byte ASCII-extension prefix', {
      expect('café au lait').to.start-with('café');
    }

    it 'matches a CJK prefix', {
      expect('日本語のテスト').to.start-with('日本');
    }

    it 'matches an emoji prefix', {
      expect('🚀 to the moon').to.start-with('🚀');
    }

    it 'matches a combining-character grapheme prefix', {
      expect('ïmpression').to.start-with('ï');
    }
  }

  describe 'case sensitivity', {
    it 'is case sensitive', {
      my @captured = capture-failures {
        expect('Hello world').to.start-with('hello');
      };
      expect(@captured.elems).to.be(1);
    }

    it 'matches when case matches exactly', {
      expect('Hello world').to.start-with('Hello');
    }
  }

  describe 'numeric stringification of prefix args', {
    it 'coerces an Int prefix to its string form', {
      expect('42 is the answer').to.start-with(42);
    }

    it 'coerces a Rat prefix to its string form', {
      expect('3.14 radians').to.start-with(3.14);
    }
  }

  describe 'allomorph and Stringy haystacks', {
    it 'treats an IntStr allomorph as a string', {
      my $allo = <42>;
      expect($allo).to.start-with('4');
    }

    it 'treats a RatStr allomorph as a string', {
      my $allo = <3.14>;
      expect($allo).to.start-with('3.');
    }
  }
}

describe 'end-with matcher with string varieties', {
  describe 'empty strings', {
    it 'matches the empty suffix on a non-empty string', {
      expect('hello').to.end-with('');
    }

    it 'matches the empty suffix on the empty string', {
      expect('').to.end-with('');
    }

    it 'fails to find a non-empty suffix on the empty string', {
      my @captured = capture-failures {
        expect('').to.end-with('a');
      };
      expect(@captured.elems).to.be(1);
    }
  }

  describe 'whitespace and special characters', {
    it 'matches a trailing space', {
      expect('trailing ').to.end-with(' ');
    }

    it 'matches a trailing tab', {
      expect("hello\t").to.end-with("\t");
    }

    it 'matches a trailing newline', {
      expect("done\n").to.end-with("\n");
    }

    it 'matches a suffix containing punctuation', {
      expect('end of sentence.').to.end-with('.', 'sentence.');
    }

    it 'distinguishes trailing whitespace', {
      my @captured = capture-failures {
        expect('hello').to.end-with('hello ');
      };
      expect(@captured.elems).to.be(1);
    }
  }

  describe 'multi-line strings', {
    my $text = "first line\nsecond line";

    it 'matches a suffix on the last line', {
      expect($text).to.end-with('second line');
    }

    it 'matches a suffix that spans the line boundary', {
      expect($text).to.end-with("line\nsecond line");
    }

    it 'fails when the suffix lives on an earlier line', {
      my @captured = capture-failures {
        expect($text).to.end-with('first');
      };
      expect(@captured.elems).to.be(1);
    }
  }

  describe 'Unicode strings', {
    it 'matches a multi-byte ASCII-extension suffix', {
      expect('le café').to.end-with('café');
    }

    it 'matches a CJK suffix', {
      expect('日本語のテスト').to.end-with('テスト');
    }

    it 'matches an emoji suffix', {
      expect('to the moon 🚀').to.end-with('🚀');
    }
  }

  describe 'case sensitivity', {
    it 'is case sensitive', {
      my @captured = capture-failures {
        expect('Hello World').to.end-with('world');
      };
      expect(@captured.elems).to.be(1);
    }

    it 'matches when case matches exactly', {
      expect('Hello World').to.end-with('World');
    }
  }

  describe 'numeric stringification of suffix args', {
    it 'coerces an Int suffix to its string form', {
      expect('answer = 42').to.end-with(42);
    }

    it 'coerces a Rat suffix to its string form', {
      expect('value: 3.14').to.end-with(3.14);
    }
  }

  describe 'allomorph and Stringy haystacks', {
    it 'treats an IntStr allomorph as a string', {
      my $allo = <42>;
      expect($allo).to.end-with('2');
    }

    it 'treats a RatStr allomorph as a string', {
      my $allo = <3.14>;
      expect($allo).to.end-with('14');
    }
  }
}
