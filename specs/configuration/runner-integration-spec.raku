use BDD::Behave;
use BDD::Behave::Configuration;
use BDD::Behave::Runner;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecTree;
use BDD::Behave::Formatter::Tree;

constant Configuration = BDD::Behave::Configuration::Configuration;
constant Runner        = BDD::Behave::Runner::Runner;
constant Suite         = BDD::Behave::SpecTree::Suite;
constant ExampleGroup  = BDD::Behave::SpecTree::ExampleGroup;
constant Example       = BDD::Behave::SpecTree::Example;

# Shared helpers for the runner integration specs.
class CounterHelper {
  has Int $.count is rw = 0;
  method tick { $!count++ }
}

class GreetHelper {
  method hello { 'hello' }
}

sub fresh-registry { BDD::Behave::SpecRegistry::SpecRegistry.new }

sub make-suite($description) {
  Suite.create(:$description, :file('runner-int'.IO));
}

sub make-group($description, $parent) {
  my $g = ExampleGroup.new(:$description, :file('runner-int'.IO), :line(1));
  $parent.add-group($g);
  $g;
}

sub make-example(Str $description, &block, $parent, *%meta) {
  my $ex = Example.new(:$description, :file('runner-int'.IO), :line(1), :&block);
  $ex.set-metadata(|%meta) if %meta.elems;
  $parent.add-example($ex);
  $ex;
}

sub run-quiet($suite, $cfg) {
  my $sink = open '/dev/null', :w;
  my $runner = Runner.new(
    :formatter(BDD::Behave::Formatter::Tree.new),
    :order<defined>,
    :config($cfg),
  );
  {
    my $*OUT = $sink;
    $runner.run($suite);
  }
  $sink.close;
  $runner;
}

describe 'Runner + Configuration: helper inclusion', {
  it 'exposes included helpers via $*BEHAVE-HELPERS by short class name', {
    my $cfg = Configuration.new;
    $cfg.include(GreetHelper);
    my $suite = make-suite('greet-suite');
    my $captured;
    make-example('uses helper', { $captured = $*BEHAVE-HELPERS<GreetHelper>.hello }, $suite);

    run-quiet($suite, $cfg);
    expect($captured).to.eq('hello');
  }

  it 'aliases helpers via :as<name>', {
    my $cfg = Configuration.new;
    $cfg.include(GreetHelper, :as<greet>);
    my $suite = make-suite('alias-suite');
    my $captured;
    make-example('uses aliased helper', { $captured = $*BEHAVE-HELPERS<greet>.hello }, $suite);

    run-quiet($suite, $cfg);
    expect($captured).to.eq('hello');
  }

  it 'reuses one helper instance across the whole run', {
    my $cfg = Configuration.new;
    $cfg.include(CounterHelper);
    my $suite = make-suite('counter-suite');
    make-example('first',  { $*BEHAVE-HELPERS<CounterHelper>.tick }, $suite);
    make-example('second', { $*BEHAVE-HELPERS<CounterHelper>.tick }, $suite);
    make-example('third',  { $*BEHAVE-HELPERS<CounterHelper>.tick }, $suite);

    my $runner = run-quiet($suite, $cfg);
    # Helpers persist across examples — first tick from example 1, etc.
    my $helper = $*BEHAVE-HELPERS<CounterHelper> // CounterHelper;
    expect($runner.result.passed).to.eq(3);
  }
}

describe 'Runner + Configuration: global hooks', {
  it 'runs config before-all once before any example', {
    my $cfg = Configuration.new;
    my @order;
    $cfg.before-all({ @order.push: 'cfg-before-all' });
    my $suite = make-suite('hook-suite');
    make-example('one', { @order.push: 'ex1' }, $suite);
    make-example('two', { @order.push: 'ex2' }, $suite);

    run-quiet($suite, $cfg);
    expect(@order.List).to.eq(<cfg-before-all ex1 ex2>.List);
  }

  it 'runs config after-all once after all examples', {
    my $cfg = Configuration.new;
    my @order;
    $cfg.after-all({ @order.push: 'cfg-after-all' });
    my $suite = make-suite('after-suite');
    make-example('one', { @order.push: 'ex1' }, $suite);
    make-example('two', { @order.push: 'ex2' }, $suite);

    run-quiet($suite, $cfg);
    expect(@order.List).to.eq(<ex1 ex2 cfg-after-all>.List);
  }

  it 'runs config before-each and after-each around every example', {
    my $cfg = Configuration.new;
    my @order;
    $cfg.before-each({ @order.push: 'be' });
    $cfg.after-each({ @order.push: 'ae' });
    my $suite = make-suite('each-suite');
    make-example('one', { @order.push: 'ex1' }, $suite);
    make-example('two', { @order.push: 'ex2' }, $suite);

    run-quiet($suite, $cfg);
    expect(@order.List).to.eq(<be ex1 ae be ex2 ae>.List);
  }

  it 'runs config around-each wrapping every example', {
    my $cfg = Configuration.new;
    my @order;
    $cfg.around-each(-> &next {
      @order.push: 'around-pre';
      next();
      @order.push: 'around-post';
    });
    my $suite = make-suite('around-suite');
    make-example('one', { @order.push: 'ex1' }, $suite);

    run-quiet($suite, $cfg);
    expect(@order.List).to.eq(<around-pre ex1 around-post>.List);
  }

  it 'config hook is filtered by :tag', {
    my $cfg = Configuration.new;
    my @order;
    $cfg.before-each({ @order.push: 'tag-only' }, :tag<wanted>);
    my $suite = make-suite('filtered-suite');
    make-example('included', { @order.push: 'in'  }, $suite, :tags(['wanted']));
    make-example('excluded', { @order.push: 'out' }, $suite, :tags(['other']));

    run-quiet($suite, $cfg);
    expect(@order.List).to.eq(<tag-only in out>.List);
  }
}

describe 'Runner + Configuration: metadata filters', {
  it 'filter(:key<value>) keeps only matching examples', {
    my $cfg = Configuration.new;
    $cfg.filter(:type<unit>);
    my $suite = make-suite('meta-suite');
    make-example('unit one', { Nil }, $suite, :type<unit>);
    make-example('unit two', { Nil }, $suite, :type<unit>);
    make-example('integ one', { Nil }, $suite, :type<integration>);

    my $runner = run-quiet($suite, $cfg);
    expect($runner.result.passed).to.eq(2);
    expect($runner.result.total).to.eq(2);
  }

  it 'filter(:flag) treats truthy metadata as a boolean filter', {
    my $cfg = Configuration.new;
    $cfg.filter(:db);
    my $suite = make-suite('flag-suite');
    make-example('db one',   { Nil }, $suite, :db);
    make-example('no flag',  { Nil }, $suite);

    my $runner = run-quiet($suite, $cfg);
    expect($runner.result.passed).to.eq(1);
  }

  it 'exclude-filter drops examples whose metadata matches', {
    my $cfg = Configuration.new;
    $cfg.exclude-filter(:slow);
    my $suite = make-suite('excl-suite');
    make-example('fast',  { Nil }, $suite);
    make-example('slow1', { Nil }, $suite, :slow);
    make-example('slow2', { Nil }, $suite, :slow);

    my $runner = run-quiet($suite, $cfg);
    expect($runner.result.passed).to.eq(1);
  }

  it 'CLI tag and config metadata filter compose with AND', {
    my $cfg = Configuration.new;
    $cfg.filter(:type<unit>);
    my $suite = make-suite('and-suite');
    make-example('unit + wanted',   { Nil }, $suite,
                 :type<unit>, :tags(['wanted']));
    make-example('unit no tag',     { Nil }, $suite, :type<unit>);
    make-example('integ + wanted',  { Nil }, $suite,
                 :type<integration>, :tags(['wanted']));

    my $sink = open '/dev/null', :w;
    my $runner = Runner.new(
      :formatter(BDD::Behave::Formatter::Tree.new),
      :order<defined>,
      :config($cfg),
      :include-tags(<wanted>),
    );
    {
      my $*OUT = $sink;
      $runner.run($suite);
    }
    $sink.close;
    expect($runner.result.passed).to.eq(1);
  }
}

describe 'Runner + Configuration: filter-run-when-matching', {
  it 'applies the filter when at least one example matches', {
    my $cfg = Configuration.new;
    $cfg.filter-run-when-matching(:focus);
    my $suite = make-suite('frwm-match');
    make-example('focused',  { Nil }, $suite, :focus);
    make-example('other 1',  { Nil }, $suite);
    make-example('other 2',  { Nil }, $suite);

    my $runner = run-quiet($suite, $cfg);
    expect($runner.result.passed).to.eq(1);
  }

  it 'is silently dropped when no example matches', {
    my $cfg = Configuration.new;
    $cfg.filter-run-when-matching(:focus);
    my $suite = make-suite('frwm-drop');
    make-example('one',   { Nil }, $suite);
    make-example('two',   { Nil }, $suite);
    make-example('three', { Nil }, $suite);

    my $runner = run-quiet($suite, $cfg);
    expect($runner.result.passed).to.eq(3);
  }

  it 'composes with other CLI filters under AND', {
    my $cfg = Configuration.new;
    $cfg.filter-run-when-matching(:focus);
    my $suite = make-suite('frwm-and');
    make-example('focus + wanted', { Nil }, $suite, :focus, :tags(['wanted']));
    make-example('focus only',     { Nil }, $suite, :focus);
    make-example('plain',          { Nil }, $suite);

    my $sink = open '/dev/null', :w;
    my $runner = Runner.new(
      :formatter(BDD::Behave::Formatter::Tree.new),
      :order<defined>,
      :config($cfg),
      :include-tags(<wanted>),
    );
    {
      my $*OUT = $sink;
      $runner.run($suite);
    }
    $sink.close;
    expect($runner.result.passed).to.eq(1);
  }

  it 'supports a string key (no value) defaulting to truthy', {
    my $cfg = Configuration.new;
    $cfg.filter-run-when-matching('wip');
    my $suite = make-suite('frwm-str');
    make-example('wip one', { Nil }, $suite, :wip);
    make-example('rest',    { Nil }, $suite);

    my $runner = run-quiet($suite, $cfg);
    expect($runner.result.passed).to.eq(1);
  }
}
