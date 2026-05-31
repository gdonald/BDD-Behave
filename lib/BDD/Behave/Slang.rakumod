use nqp;

# When a `let(:NAME, { ... })` statement (or let-bang / subject) is parsed,
# install a lexical accessor NAME in the enclosing scope that resolves to
# $*LET-RUNTIME.value('NAME') at runtime.
#
# engage-let-slang must be called from the EXPORT sub so that $*LANG / $*W
# refer to the spec's compilation.

sub engage-let-slang() is export {
  my $original-actions := %*LANG<MAIN-actions>;
  my %installed-names;

  my role LetSlangActions {
    method statement(Mu $cursor is raw) {
      my $match := nqp::decont($cursor);
      nqp::findmethod($original-actions, 'statement')(self, $match);

      my $text = nqp::box_s(nqp::findmethod($match, 'Str')($match), Str);

      if $text ~~ /^ \s* ['let-bang' | 'let' | 'subject'] \s* '(' \s*
                     [ ':' $<name>=<[\w\-]>+
                     | <['"]> $<name>=<-['"]>+ <['"]> ] / {
        my $name = ~$<name>;
        my $pad := $*W.cur_lexpad;

        unless %installed-names{$name} {
          my %symbol := $pad.symbol('&' ~ $name);

          if %symbol.elems {
            note "[BDD::Behave] let(:$name) shadows an existing '$name' in the same scope";
          }
        }

        %installed-names{$name} = True;

        my $resolver := anon sub () { $*LET-RUNTIME.value($name) };
        $*W.install_lexical_symbol($pad, '&' ~ $name, $resolver);
      }
    }
  }

  my $grammar := %*LANG<MAIN>;
  my $actions := %*LANG<MAIN-actions>.^mixin(LetSlangActions);
  $*LANG.define_slang('MAIN', $grammar, $actions);
}
