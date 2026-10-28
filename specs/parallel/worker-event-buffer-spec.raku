use BDD::Behave;
use BDD::Behave::Parallel::EventStream;
use BDD::Behave::Formatter::Progress;
use BDD::Behave::Formatter::TAP;

sub event-types(@events --> List) {
  @events.map(*<type>).List;
}

describe 'WorkerEventBuffer', {
  let(:buffer, { WorkerEventBuffer.new });

  it 'holds an event until its worker file ends', {
    expect(buffer.hold(0, %( :type<group-start> )).elems).to.be(0);
  }

  context 'when a worker reports the end of its file', {
    before-each {
      buffer.hold(0, %( :type<suite-start> ));
      buffer.hold(1, %( :type<example-pass> ));
      buffer.hold(0, %( :type<group-start> ));
    }

    it 'releases that worker events in the order they arrived', {
      expect(event-types(buffer.hold(0, %( :type<suite-end> )))).to.eq(<suite-start group-start suite-end>);
    }

    it 'keeps holding the events of other workers', {
      buffer.hold(0, %( :type<suite-end> ));

      expect(event-types(buffer.release(1))).to.eq(('example-pass',));
    }
  }

  context 'when a worker is released without ending its file', {
    before-each {
      buffer.hold(2, %( :type<group-start> ));
      buffer.hold(2, %( :type<example-pass> ));
    }

    it 'returns the held events', {
      expect(event-types(buffer.release(2))).to.eq(<group-start example-pass>);
    }

    it 'returns nothing on a second release', {
      buffer.release(2);

      expect(buffer.release(2).elems).to.be(0);
    }
  }

  context 'when every worker is released at once', {
    before-each {
      buffer.hold(1, %( :type<example-fail> ));
      buffer.hold(0, %( :type<example-pass> ));
    }

    it 'pairs each worker index with its events, in worker order', {
      expect(buffer.release-all.map({ .key => event-types(.value) }).List)
        .to.eq((0 => ('example-pass',), 1 => ('example-fail',)));
    }

    it 'leaves nothing held afterwards', {
      buffer.release-all;

      expect(buffer.release-all.elems).to.be(0);
    }
  }

  it 'holds an event that has no type', {
    expect(buffer.hold(0, %( :raw<text> )).elems).to.be(0);
  }

  context 'when it passes events through', {
    let(:buffer, { WorkerEventBuffer.new(:pass-through) });

    it 'returns each event as soon as it arrives', {
      expect(event-types(buffer.hold(0, %( :type<example-pass> )))).to.eq(('example-pass',));
    }

    it 'has nothing left to release', {
      buffer.hold(0, %( :type<example-pass> ));

      expect(buffer.release-all.elems).to.be(0);
    }
  }
}

describe 'which formatters need whole files from each worker', {
  it 'gives the tap formatter whole files', {
    expect(BDD::Behave::Formatter::TAP.new.needs-whole-files).to.be-truthy;
  }

  it 'streams events to the progress formatter as they arrive', {
    expect(BDD::Behave::Formatter::Progress.new.needs-whole-files).to.be-falsy;
  }
}
