#!/usr/bin/env perl6

use v6.d;
use lib 'lib';
use Grammar;
use Actions;
use Utils;

for Utils.specs -> $spec {
  say $spec;

  my $result = Grammar.parse($spec.IO.slurp.trim, :actions(Actions));

  for $result<describe> -> $describe {
    my $it = $describe<it>;
    my $expectation = $it<expectation>;
    my $given = $expectation<given>;
    my $expected = $expectation<expected>;

    say '  ' ~ $describe<describe-description>.Str;
    say '    ' ~ $it<it-description>.Str;
    say '      ' ~ (($given) == ($expected) ?? 'SUCCESS' !! 'FAILURE');
    say '';
  }
}
