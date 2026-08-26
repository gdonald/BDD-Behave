use BDD::Behave;
use BDD::Behave::SpecTree;

constant Example = BDD::Behave::SpecTree::Example;

describe 'running the block of an example', {
  context 'given a block that takes a context argument', {
    let(:seen, { [] });

    let(:example, {
      my @seen := seen();

      Example.new(
        :description('takes a context'),
        :file('specs/example.raku'),
        :line(1),
        :block(-> $context { @seen.push($context.defined) }),
      );
    });

    it 'hands the block a context', {
      example().execute;

      expect(seen()[0]).to.be-truthy;
    }

    it 'hands the block a context on every run', {
      example().execute for ^3;

      expect(seen().elems).to.be(3);
    }
  }

  context 'given a block that takes no argument at all', {
    let(:runs, { [] });

    let(:example, {
      my @runs := runs();

      Example.new(
        :description('takes nothing'),
        :file('specs/example.raku'),
        :line(2),
        :block(sub { @runs.push(1) }),
      );
    });

    it 'runs the block', {
      example().execute;

      expect(runs().elems).to.be(1);
    }

    it 'runs the block again on a repeat run', {
      example().execute for ^3;

      expect(runs().elems).to.be(3);
    }
  }

  context 'given a block that takes only named arguments', {
    let(:values, { [] });

    let(:example, {
      my @values := values();

      Example.new(
        :description('takes a named argument'),
        :file('specs/example.raku'),
        :line(3),
        :block(-> :$value { @values.push($value) }),
      );
    });

    it 'forwards the named argument rather than a context', {
      example().execute(:value(7));

      expect(values()[0]).to.be(7);
    }
  }
}
