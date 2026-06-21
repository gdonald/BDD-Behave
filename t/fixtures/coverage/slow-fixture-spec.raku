use BDD::Behave;

# Sleeps briefly so a parent `behave --coverage` run stays alive long enough for
# the coverage-cleanup test to observe the temp dir and send an interrupt.
describe 'slow', {
  it 'stays busy so the run can be interrupted', {
    sleep 3;
    expect(True).to.be(True);
  }
}
