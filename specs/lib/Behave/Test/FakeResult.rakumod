unit module Behave::Test::FakeResult;

class FakeResult is export {
  has Int $.total   is rw = 0;
  has Int $.passed  is rw = 0;
  has Int $.failed  is rw = 0;
  has Int $.pending is rw = 0;
  has Int $.skipped is rw = 0;
}

sub fake-result(%counts) is export {
  FakeResult.new(|%counts);
}
