use nqp;

# Parse-time slang engaged by `use BDD::Behave`. When a `let(:NAME, { ... })`
# statement (or let-bang / subject) is parsed, install a lexical accessor NAME
# in the enclosing scope that resolves to $*LET-RUNTIME.value('NAME') at
# runtime. See LET.md. The runtime is untouched; this is pure sugar.
#
# engage-let-slang must be called from the EXPORT sub of the module the spec
# `use`s, so that $*LANG / $*W refer to the spec's compilation.

sub engage-let-slang() is export {
  my $orig := %*LANG<MAIN-actions>;
  my %installed;

  my role LetSlangActions {
    method statement(Mu $cursor is raw) {
      my $m := nqp::decont($cursor);
      nqp::findmethod($orig, 'statement')(self, $m);

      my $text = nqp::box_s(nqp::findmethod($m, 'Str')($m), Str);

      if $text ~~ /^ \s* ['let-bang' | 'let' | 'subject'] \s* '(' \s*
                     [ ':' $<n>=<[\w\-]>+
                     | <['"]> $<n>=<-['"]>+ <['"]> ] / {
        my $name = ~$<n>;
        my $pad := $*W.cur_lexpad;

        unless %installed{$name} {
          my %sym := $pad.symbol('&' ~ $name);
          if %sym.elems {
            note "[BDD::Behave] let(:$name) shadows an existing '$name' in the same scope";
          }
        }

        %installed{$name} = True;

        my $resolver := anon sub () { $*LET-RUNTIME.value($name) };
        $*W.install_lexical_symbol($pad, '&' ~ $name, $resolver);
      }
    }
  }

  my $grammar := %*LANG<MAIN>;
  my $actions := %*LANG<MAIN-actions>.^mixin(LetSlangActions);
  $*LANG.define_slang('MAIN', $grammar, $actions);
}
