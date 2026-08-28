use BDD::Behave;

# Declaring a let inside a running example registers it with the runtime and
# hands the value straight back. Naming it through a variable keeps the slang
# out of the way, so what is left is the sub's own return.
describe 'a let declared inside a running example', {
  it 'reads back the value its block returns', {
    my $name = 'temperature';
    my $value = let($name, { 41 });

    expect($value).to.eq(41);
  }

  it 'reads the same value back through the fetch form', {
    my $name = 'altitude';
    let($name, { 500 });

    expect(let($name)).to.eq(500);
  }

  it 'evaluates its block once the name is declared', {
    my $calls = 0;
    my $name  = 'depth';
    let($name, { $calls++; 7 });

    expect($calls).to.eq(1);
  }

  it 'evaluates its block only once however often the name is read', {
    my $calls = 0;
    my $name  = 'pressure';
    let($name, { $calls++; 3 });

    let($name);
    let($name);

    expect($calls).to.eq(1);
  }
}
