
class Indent {
  my Int $.value = 0;

  method increase {
    Indent.value += 2;
  }

  method decrease {
    Indent.value -= 2;
  }

  method get {
    ' ' x Indent.value;
  }
}
