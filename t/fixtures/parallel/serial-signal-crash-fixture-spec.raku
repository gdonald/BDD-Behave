use BDD::Behave;

describe 'serial signal crash fixture', {
  it 'dies by a real signal mid-example in the serial worker', :serial, {
    run 'kill', '-SEGV', $*PID.Str;
    sleep 5;
  }
}
