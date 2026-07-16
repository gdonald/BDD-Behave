use BDD::Behave;

describe 'signal crash fixture', {
  it 'dies by a real signal mid-example', {
    run 'kill', '-SEGV', $*PID.Str;
    sleep 5;
  }
}
