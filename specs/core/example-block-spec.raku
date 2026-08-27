use BDD::Behave;
use BDD::Behave::SpecTree;
use BDD::Behave::LetRuntime;

constant Example = BDD::Behave::SpecTree::Example;

# Behave runs these examples with a let runtime in scope, so the branch that
# builds one is reached by hiding it for the length of one call.
sub execute-without-runtime($example) {
  my $*LET-RUNTIME = Nil;
  $example.execute;
}

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

  # Running inside behave means a let runtime is already in scope, so the branch
  # that builds one is reached by shadowing the dynamic variable with Nil.
  context 'given an example run with no let runtime in scope', {
    let(:seen, { [] });

    let(:example, {
      my @seen := seen();

      Example.new(
        :description('reads a let'),
        :file('specs/example.raku'),
        :line(4),
        :block(-> $context { @seen.push($*LET-RUNTIME.value('a-value')) }),
      );
    });

    before-each {
      example().set-metadata(:lets([
        BDD::Behave::LetRuntime::LetDefinition.new(:name('a-value'), :block({ 'from the let' })),
      ]));
    }

    it 'builds a runtime from the lets the example carries', {
      execute-without-runtime(example());

      expect(seen()[0]).to.eq('from the let');
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
