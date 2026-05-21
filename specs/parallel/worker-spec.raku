use BDD::Behave;
use BDD::Behave::Worker;

describe 'BDD::Behave::Worker.id and .count', {
  it 'returns 0 / 1 when env vars are unset', {
    %*ENV<BEHAVE_WORKER_INDEX>:delete;
    %*ENV<BEHAVE_WORKER_COUNT>:delete;
    expect(BDD::Behave::Worker.id).to.be(0);
    expect(BDD::Behave::Worker.count).to.be(1);
  }

  it 'reads BEHAVE_WORKER_INDEX and BEHAVE_WORKER_COUNT', {
    %*ENV<BEHAVE_WORKER_INDEX> = '2';
    %*ENV<BEHAVE_WORKER_COUNT> = '5';
    expect(BDD::Behave::Worker.id).to.be(2);
    expect(BDD::Behave::Worker.count).to.be(5);
    %*ENV<BEHAVE_WORKER_INDEX>:delete;
    %*ENV<BEHAVE_WORKER_COUNT>:delete;
  }

  it 'falls back to defaults on garbage values', {
    %*ENV<BEHAVE_WORKER_INDEX> = 'nope';
    %*ENV<BEHAVE_WORKER_COUNT> = '0';
    expect(BDD::Behave::Worker.id).to.be(0);
    expect(BDD::Behave::Worker.count).to.be(1);
    %*ENV<BEHAVE_WORKER_INDEX>:delete;
    %*ENV<BEHAVE_WORKER_COUNT>:delete;
  }
}
