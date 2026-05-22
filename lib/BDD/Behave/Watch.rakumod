unit module BDD::Behave::Watch;

use BDD::Behave::Watch::Watcher;
use BDD::Behave::Watch::SmartSelector;
use BDD::Behave::Watch::UI;
use BDD::Behave::Watch::Session;

our sub default-paths(IO::Path :$base = $*CWD --> List) {
  my @paths;
  for <lib specs> -> $name {
    my $p = $base.add($name);
    @paths.push: $p if $p.e;
  }
  @paths.List;
}

our sub default-watcher(@paths --> BDD::Behave::Watch::Watcher::Watcher) {
  my $w = BDD::Behave::Watch::Watcher::Watcher.new;
  $w.add-path($_) for @paths;
  $w;
}

our sub default-selector(IO::Path :$lib-root --> BDD::Behave::Watch::SmartSelector::Selector) {
  BDD::Behave::Watch::SmartSelector::Selector.new(:$lib-root);
}

our sub make-subprocess-runner(
  :@base-argv!,
  IO::Path :$cwd,
  IO::Path :$failures-path,
  Bool :$enable-color = True,
  --> Callable
) {
  return -> $req {
    my @argv = @base-argv;
    if $req.only-failures {
      @argv.push: '--only-failures';
      @argv.push: '--failures-path', $failures-path.absolute
        if $failures-path.defined;
    }
    for $req.specs.list -> $spec {
      @argv.push: $spec.absolute;
    }
    my %env = |%*ENV;
    %env<BEHAVE_DISABLE_CONFIG> = '1' if %env<BEHAVE_DISABLE_CONFIG>:!exists;
    my @args = @argv[1..*];
    my $proc;
    if $cwd.defined {
      $proc = run(@argv[0], |@args, :env(%env), :cwd($cwd.absolute));
    } else {
      $proc = run(@argv[0], |@args, :env(%env));
    }
    $proc.exitcode;
  };
}
