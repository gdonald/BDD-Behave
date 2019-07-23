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

  rule describe { <desc> <dbl-qt><describe-description><dbl-qt> <do><space><nl><space><it><_end> }
  rule it { <_it> <dbl-qt><it-description><dbl-qt> <do><space><nl><expectation><nl>?<_end> }
  rule expectation { <space><expect><open_paren><given><close_paren><dot><_to> <eq><open_paren><expected><close_paren><space> }

  rule TOP { <describe>* %% "" }
}
