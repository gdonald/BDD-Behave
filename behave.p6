#!/usr/bin/env perl6

use v6.d;

my $spec = q:to/END/;
describe "this spec" do
  it "is successful" do
    expect(42).to eq(42)
  end
end

describe "this other spec" do
  it "is a big failure" do
    expect(42).to eq(41)
  end
end
END

grammar Grammar {
  token dot { \. }
  token nl { "\n" }
  token space { \h* }
  token dbl-qt { '"' }
  token open_paren { '(' }
  token close_paren { ')' }
  token number { \d+ }
  token given { <number> }
  token expected { <number> }
  token word { \w+ }
  rule phrase { <word> [<.ws> <word>]* }
  token desc { 'describe' }
  token _it { 'it' }
  token do { 'do' }
  token _end { 'end' }
  token expect { 'expect' }
  token _to { 'to' }
  token eq { 'eq' }

  token describe-description { <phrase> }
  token it-description { <phrase> }

  rule describe { <desc> <dbl-qt><describe-description><dbl-qt> <do><space><nl><space><it><_end><nl> }
  rule it { <_it> <dbl-qt><it-description><dbl-qt> <do><space><nl><expectation><_end> }
  rule expectation { <space><expect><open_paren><given><close_paren><dot><_to> <eq><open_paren><expected><close_paren><space><nl> }

  rule TOP { <describe>* %% "" }
}

class Actions {
  method describe-block($/) {}
  method it($/) {}
  method expectation($/) {}
}

say $*ARGFILES.path.Str;
my $result = Grammar.parse($spec, :actions(Actions));

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
