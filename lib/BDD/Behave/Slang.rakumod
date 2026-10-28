use nqp;
use BDD::Behave::Callsite;

# When a `let(:NAME, { ... })` statement (or let-bang / subject) is parsed,
# install a lexical accessor NAME in the enclosing scope that resolves to
# $*LET-RUNTIME.value('NAME') at runtime.
#
# engage-let-slang must be called from the EXPORT sub so that $*LANG and the
# compiler's world ($*W) or resolver ($*R, under RakuAST) refer to the spec's
# compilation.

sub has-lexical(Str $symbol --> Bool) {
  with $*R {
    return so nqp::isconcrete($*R.resolve-lexical($symbol, :current-scope-only));
  }

  so $*W.cur_lexpad.symbol($symbol).elems;
}

sub install-lexical(Str $symbol, $value) {
  with $*R {
    my $declaration := ::('RakuAST::VarDeclaration::Implicit::Constant').new(:name($symbol), :$value);
    $*R.current-scope.merge-generated-lexical-declaration($declaration, :resolver($*R), :force);
    return;
  }

  $*W.install_lexical_symbol($*W.cur_lexpad, $symbol, $value);
}

# Under RakuAST a block reports the line of its first statement rather than the
# line it opens on, so a direct call to one of these is told the line it starts
# on. The legacy frontend reports the opening line, so it needs no argument.
constant DECLARED-LINE is export = 'declared-at-line';

my constant LINE-AWARE-CALLS = set <
  describe context fdescribe xdescribe fcontext xcontext
  it fit xit specify example pending let let-bang shared-examples
>;

# A let named after one of these, or a sub of the spec's own, takes the name
# over, so the argument goes only to a call that still reaches behave's routine.
sub calls-behave-routine(Str $name --> Bool) {
  my $declaration := $*R.resolve-lexical('&' ~ $name);
  return False unless nqp::isconcrete($declaration);

  my $routine := $declaration.compile-time-value;

  so $routine ~~ Routine && $routine.name eq $name && is-behave-source($routine.file);
}

sub add-declared-line(Mu $match, Str $text) {
  return without $*R;

  my $statement := nqp::findmethod($match, 'ast')($match);
  return unless $statement ~~ ::('RakuAST::Statement::Expression');

  my $call := $statement.expression;
  return unless $call ~~ ::('RakuAST::Call::Name');
  return unless $call.name.is-identifier;

  my $name = $call.name.simple-identifier;
  return unless $name (elem) LINE-AWARE-CALLS && calls-behave-routine($name);

  my $start = nqp::findmethod($match, 'from')($match) + ($text ~~ /^ \s*/).chars;
  my $line = nqp::getcomp('Raku').lineof(nqp::findmethod($match, 'orig')($match), $start, :cache(1));

  $call.args.push: ::('RakuAST::ColonPair::Value').new(
    :key(DECLARED-LINE),
    :value(::('RakuAST::IntLiteral').new($line)),
  );
}

sub engage-let-slang() is export {
  my $original-actions := $*LANG.slang_actions('MAIN');
  my %installed-names;

  my role LetSlangActions {
    method statement(Mu $cursor is raw) {
      my $match := nqp::decont($cursor);
      nqp::findmethod($original-actions, 'statement')(self, $match);

      my $text = nqp::box_s(nqp::findmethod($match, 'Str')($match), Str);

      add-declared-line($match, $text);

      if $text ~~ /^ \s* ['let-bang' | 'let' | 'subject'] \s* '(' \s*
                     [ ':' $<name>=<[\w\-]>+
                     | <['"]> $<name>=<-['"]>+ <['"]> ] / {
        my $name = ~$<name>;

        if !%installed-names{$name} && has-lexical('&' ~ $name) {
          note "[BDD::Behave] let(:$name) shadows an existing '$name' in the same scope";
        }

        %installed-names{$name} = True;

        install-lexical('&' ~ $name, anon sub () { $*LET-RUNTIME.value($name) });
      }
    }
  }

  my $grammar := $*LANG.slang_grammar('MAIN');
  my $actions := $original-actions.^mixin(LetSlangActions);
  $*LANG.define_slang('MAIN', $grammar, $actions);
}
