use BDD::Behave;
use BDD::Behave::Parallel::WorkerPool;

describe 'a worker handle collecting stderr', {
  let(:handle, {
    BDD::Behave::Parallel::WorkerPool::WorkerHandle.new(
      :index(0),
      :manifest-path('unused'.IO),
      :exit-promise(Promise.new),
    );
  });

  context 'given no output at all', {
    it 'reports an empty string', {
      expect(handle().stderr-output).to.be('');
    }
  }

  context 'given several chunks', {
    before-each {
      handle().stderr-chunks.push($_) for ('first ', 'second ', 'third');
    }

    it 'joins the chunks in the order they arrived', {
      expect(handle().stderr-output).to.be('first second third');
    }

    it 'keeps every chunk it was handed', {
      expect(handle().stderr-chunks.elems).to.be(3);
    }
  }
}
