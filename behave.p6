#!/usr/bin/env perl6

use v6.d;

my $spec = q:to/END/;
describe "this spec" do
  it "returns true" do
    expect(42).to eq(42)
  end
end
END

grammar Grammar {
  token dot { \. }
  token nl { "\n" }
  token space { \h* }
  token quote { '"' }
  token open_paren { '(' }
  token close_paren { ')' }
  token number { \d+ }
  token given { <number> }
  token expected { <number> }
  token word { \w+ }
  rule phrase { <word> [<word>]* }
  token describe { 'describe' }
  token it { 'it' }
  token do { 'do' }
  token _end { 'end' }
  token expect { 'expect' }
  token _to { 'to' }
  token eq { 'eq' }

  token describe-description { <phrase> }
  token it-description { <phrase> }

  rule describe-block { <describe> <quote><describe-description><quote> <do><space><nl><space><it-block><_end><nl> }
  rule it-block { <it> <quote><it-description><quote> <do><space><nl><expectation><_end> }
  rule expectation { <space><expect><open_paren><given><close_paren><dot><_to> <eq><open_paren><expected><close_paren><space><nl> }

  rule statements {
    | <describe-block>
    | <it-block>
    | <expectation>
  }

  rule TOP { <statements>* %% "" }
}

class Actions {
  method describe-block($/) {

  }

  method it-block($/) {

  }

  method expectation($/) {
    say $<given> == $<expected>;
  }
}

Grammar.parse($spec, :actions(Actions));
