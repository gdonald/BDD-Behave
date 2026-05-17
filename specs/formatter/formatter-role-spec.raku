use BDD::Behave;
use BDD::Behave::Formatter;

class TestFormatter does BDD::Behave::Formatter {
  has @.events;

  method name(--> Str) { 'test' }

  method group-start($group)            { @!events.push: ('group-start',  $group.description) }
  method group-end($group)              { @!events.push: ('group-end',    $group.description) }
  method example-start($example, Bool :$auto = False)
                                        { @!events.push: ('example-start', $example.description, $auto) }
  method example-pass($example)         { @!events.push: ('example-pass', $example.description) }
  method example-fail($example, :$failure-info)
                                        { @!events.push: ('example-fail', $example.description) }
  method example-pending($example)      { @!events.push: ('example-pending', $example.description) }
  method example-skipped($example)      { @!events.push: ('example-skipped', $example.description) }
}

describe 'BDD::Behave::Formatter role', {
  it 'can be composed by a custom class', {
    my $f = TestFormatter.new;
    expect($f).to.be-a(BDD::Behave::Formatter);
  }

  it 'lets a composing class override the name method', {
    expect(TestFormatter.new.name).to.eq('test');
  }

  it 'provides no-op defaults for every hook', {
    # Methods compose into TestFormatter from the role even when not overridden.
    my $f = TestFormatter.new;
    expect({ $f.suite-loading(:file('x.raku'));    }).to.not.raise-error;
    expect({ $f.suite-start(Any, :multi-file);     }).to.not.raise-error;
    expect({ $f.suite-end(Any);                    }).to.not.raise-error;
    expect({ $f.group-around-skipped(Any);         }).to.not.raise-error;
    expect({ $f.example-around-skipped(Any);       }).to.not.raise-error;
    expect({ $f.example-slow(Any, :threshold(0.1)); }).to.not.raise-error;
    expect({ $f.example-memory-leak(Any, :threshold(10)); }).to.not.raise-error;
    expect({ $f.example-auto-description(Any, :description('x')); }).to.not.raise-error;
    expect({ $f.run-summary(Any);                  }).to.not.raise-error;
    expect({ $f.profile-summary([], :limit(0));    }).to.not.raise-error;
    expect({ $f.memory-profile-summary([], :limit(0)); }).to.not.raise-error;
    expect({ $f.benchmark-summary-section([], []); }).to.not.raise-error;
    expect({ $f.multi-file-overall(Any);           }).to.not.raise-error;
    expect({ $f.multi-file-profile(Any, [], :limit(0)); }).to.not.raise-error;
    expect({ $f.multi-file-memory-profile(Any, [], :limit(0)); }).to.not.raise-error;
    expect({ $f.multi-file-benchmark(Any, [], []); }).to.not.raise-error;
    expect({ $f.load-errors([]);                   }).to.not.raise-error;
  }
}
