use BDD::Behave;
use BDD::Behave::Formatter::JsonEvents;
use BDD::Behave::Parallel::EventStream;
use BDD::Behave::SpecTree;
use Test::Output;

constant Suite = BDD::Behave::SpecTree::Suite;

describe 'the line the json-events formatter writes', {
  let(:formatter, { BDD::Behave::Formatter::JsonEvents.new });

  sub emitted(Str $description --> Str) {
    my $suite = Suite.new(:$description, :file('/abs/spec.raku'.IO), :line(1));

    stdout-from({ formatter().suite-start($suite) }).lines[0];
  }

  sub round-tripped(Str $description --> Str) {
    parse-json-event(emitted($description))<description>;
  }

  context 'given a description carrying characters JSON reserves', {
    it 'escapes a double quote', {
      expect(emitted('a "quoted" name')).to.include('a \"quoted\" name');
    }

    it 'escapes a backslash', {
      expect(emitted('a \\ backslash')).to.include('a \\\\ backslash');
    }

    it 'escapes a newline', {
      expect(emitted("two\nlines")).to.include('two\nlines');
    }

    it 'escapes a carriage return', {
      expect(emitted("two\rlines")).to.include('two\rlines');
    }

    it 'escapes a tab', {
      expect(emitted("two\tcolumns")).to.include('two\tcolumns');
    }

    it 'reads every reserved character back unchanged', {
      expect(round-tripped("a \"quote\", a \\ backslash, a\nnewline, a\ttab"))
        .to.eq("a \"quote\", a \\ backslash, a\nnewline, a\ttab");
    }
  }

  context 'given a description carrying a control character with no escape of its own', {
    it 'writes the character as a unicode escape', {
      expect(emitted("bell" ~ 7.chr ~ "here")).to.include(Q[bell\u0007here]);
    }

    it 'reads the control character back unchanged', {
      expect(round-tripped("bell" ~ 7.chr ~ "here")).to.eq("bell" ~ 7.chr ~ "here");
    }
  }

  context 'given a description carrying no reserved character at all', {
    it 'writes the description through unchanged', {
      expect(emitted('a plain description'))
        .to.include('"description":"a plain description"');
    }
  }

  it 'writes the keys of an event object in sorted order', {
    my @keys = emitted('sorted keys').comb(/ '"' <( <-["]>+ )> '":' /);

    expect(@keys.join(',')).to.eq(@keys.sort.join(','));
  }
}
