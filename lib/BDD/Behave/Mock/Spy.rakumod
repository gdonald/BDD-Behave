unit module BDD::Behave::Mock::Spy;

use BDD::Behave::Mock::Double;
use BDD::Behave::Mock::Stub;

constant SPY-RESERVED-METHODS = set <
  BUILD BUILDALL DESTROY new clone perl raku gist Str
  defined DEFINITE WHAT WHO HOW WHICH WHERE so not Bool
  ACCEPTS dispatch:<.> dispatch:<.?> dispatch:<.+> dispatch:<.*>
>;

sub spy-method-candidates(Mu \cls) {
  my @names;
  my %seen;
  for cls.^methods(:local) -> $m {
    next unless $m ~~ Method;
    next if $m ~~ Submethod;
    my $name = try { $m.name };
    next unless $name.defined && $name ~~ Str;
    next if $name eq '' || $name.starts-with('!');
    next if $name (elem) SPY-RESERVED-METHODS;
    next if %seen{$name}++;
    @names.push($name);
  }
  @names;
}

our sub spy(|args) is export {
  my @pos   = args.list;
  my %named = args.hash;

  if @pos.elems == 0 && %named.elems == 0 {
    return Double.new(:double-name<spy>);
  }

  if @pos.elems == 1 && %named.elems == 0 {
    my \arg = @pos[0];
    if arg.defined && arg.DEFINITE && arg !~~ Str {
      my $cls = arg.WHAT;
      for spy-method-candidates($cls) -> $name {
        my $stub = Stub.new(:target(arg), :method-name($name));
        $stub.install;
        StubRegistry.register($stub);
        $stub.and-call-original;
      }
      return arg;
    }
  }

  double(|args);
}
