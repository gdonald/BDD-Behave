


describe -> "this spec" {
  it -> "is succesful" {
    expect(42).to_eq(42);
  }
}

describe -> "this other spec" {
  it -> "is a big failure" {
    expect(42).to_eq(41);
  }
}

describe -> "this spec has contexts" {
  context -> "with an it block" {
    it -> "is succesful" {
      expect(42).to_eq(42);
    }
  }

  context -> "with more than one it block" {
    it -> "is succesful" {
      expect(42).to_eq(42);
    }


    it -> "is a big failure" {
      expect(42).to_eq(41);
    }
  }
}
