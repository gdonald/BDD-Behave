use BDD::Behave;

my class Mailer {
  method deliver($message) { $message }
  method address { 'nowhere' }
}

describe 'a double standing in for a class', {
  it 'takes the short name of the class it stands for', {
    expect(double(Mailer).double-name).to.eq('Mailer');
  }

  it 'answers a method the class has', {
    expect(double(Mailer, :address('here')).address).to.eq('here');
  }

  context 'given a stub for a method the class does not have', {
    it 'refuses at construction', {
      expect({ double(Mailer, :missing('x')) })
        .to.raise-error(/"cannot stub 'missing'"/);
    }

    it 'names the class in the refusal', {
      expect({ double(Mailer, :missing('x')) }).to.raise-error(/'Mailer has no such method'/);
    }

    it 'refuses a stub added later', {
      expect({ double(Mailer).add-stub(:missing('x')) })
        .to.raise-error(/"cannot stub 'missing'"/);
    }
  }

  context 'given a call to a method the class does not have', {
    it 'refuses the call', {
      expect({ double(Mailer).missing })
        .to.raise-error(/"has no method 'missing'"/);
    }
  }

  context 'given a stub added later for a method the class has', {
    it 'answers with it', {
      expect(double(Mailer).add-stub(:address('later')).address).to.eq('later');
    }
  }
}

describe 'a double built without a class behind it', {
  it 'takes the name it was given', {
    expect(double('Logger').double-name).to.eq('Logger');
  }

  it 'is anonymous when it was given no name', {
    expect(double().double-name).to.eq('anonymous');
  }

  it 'answers any method it was stubbed with', {
    expect(double('Logger', :level('warn')).level).to.eq('warn');
  }

  it 'refuses more than one positional argument', {
    expect({ double('Logger', Mailer) })
      .to.raise-error(/'takes at most one positional argument'/);
  }
}

describe 'allowing a method on a double built from a class', {
  it 'refuses a method the class does not have', {
    expect({ allow(double(Mailer)).to.receive('missing') })
      .to.raise-error(/"has no method 'missing'"/);
  }

  it 'allows a method the class has', {
    my $mailer = double(Mailer);
    allow($mailer).to.receive('address').and-return('stubbed');

    expect($mailer.address).to.eq('stubbed');
  }
}

describe 'the calls a double records', {
  let(:log, { double('Logger', :info(Nil)) });

  before-each {
    log().info('first');
    log().info('second');
  }

  it 'counts the calls to a method', {
    expect(log().call-count('info')).to.be(2);
  }

  it 'reports having received the method', {
    expect(log().received('info')).to.be-truthy;
  }

  it 'reports not having received a method it was never sent', {
    expect(log().received('warn')).to.be-falsy;
  }

  it 'forgets them when it is reset', {
    log().reset;

    expect(log().calls.elems).to.be(0);
  }

  it 'keeps answering stubs after a reset', {
    log().reset;

    expect(log().stubs<info>:exists).to.be-truthy;
  }
}
