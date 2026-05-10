use BDD::Behave;

class Widget {
  has $.bar;
  method greet { "hello $!bar" }
}

describe 'anonymous subject', {
  subject({ Widget.new(:bar(99)) });

  it 'is readable via :subject', {
    my $w = subject();
    expect($w.bar).to.be(99);
    expect(:subject).to.be($w);
  }

  it 'reader returns same object as :subject within an example', {
    my $a = subject();
    my $b = subject();
    expect($a).to.be($b);
  }
}

describe 'named subject', {
  subject(:widget, { Widget.new(:bar(7)) });

  it 'is accessible by its given name', {
    my $w = subject();
    expect($w.bar).to.be(7);
  }

  it 'is also accessible as :subject', {
    my $a = subject();
    expect(:subject).to.be($a);
  }

  it 'shares memoization across both names', {
    my $a = subject();
    expect(:subject).to.be($a);
    expect(:widget).to.be($a);
  }
}

describe 'subject memoization within an example', {
  my $hits = 0;
  subject({ ++$hits; 'value' });

  it 'evaluates exactly once per example', {
    my $a = subject();
    my $b = subject();
    expect($hits).to.be(1);
    expect($a).to.be($b);
  }
}

describe 'subject is lazy by default', {
  my $hits = 0;
  subject({ ++$hits; 'value' });

  it 'does not evaluate when not read', {
    expect(1).to.be(1);
    expect($hits).to.be(0);
  }
}

describe 'subject-bang eager evaluation', {
  my $eager-hits = 0;
  subject-bang({ ++$eager-hits; 'eager-value' });

  it 'forces evaluation before the example body', {
    expect($eager-hits).to.be(1);
  }

  it 'forces evaluation again for the next example', {
    expect($eager-hits).to.be(2);
  }
}

describe 'named subject-bang', {
  my $hits = 0;
  subject-bang(:user, { ++$hits; 'alice' });

  it 'evaluates eagerly and exposes the value via both names', {
    expect($hits).to.be(1);
    expect(:user).to.be('alice');
    expect(:subject).to.be('alice');
    expect($hits).to.be(1);
  }
}

describe 'subject string-name form', {
  my $hits = 0;
  subject('user', { ++$hits; 'bob' });

  it 'registers under both the given name and :subject', {
    expect(:user).to.be('bob');
    expect(:subject).to.be('bob');
    expect($hits).to.be(1);
  }
}

describe 'inner subject shadows outer subject', {
  subject({ 'outer' });

  context 'inner context', {
    subject({ 'inner' });

    it 'sees inner', {
      expect(:subject).to.be('inner');
    }
  }

  it 'still sees outer in this group', {
    expect(:subject).to.be('outer');
  }
}

describe 'inner subject-bang shadows outer subject-bang', {
  my $outer-hits = 0;
  my $inner-hits = 0;
  subject-bang({ ++$outer-hits; 'outer' });

  context 'inner', {
    subject-bang({ ++$inner-hits; 'inner' });

    it 'forces inner block and exposes inner value', {
      expect($inner-hits).to.be(1);
      expect(:subject).to.be('inner');
    }
  }
}
