use BDD::Behave;

# Deliberately slow group used to compare static LPT vs queue-mode
# work-stealing under uneven workloads (roadmap 9.8.6). Each example
# sleeps a bit; example *count* matches the fast fixtures so static
# LPT's cost proxy can't distinguish them.

describe 'uneven slow 1', {
  it 's1-a', { sleep 0.4; expect(1).to.be(1); }
  it 's1-b', { sleep 0.4; expect(1).to.be(1); }
  it 's1-c', { sleep 0.4; expect(1).to.be(1); }
}
