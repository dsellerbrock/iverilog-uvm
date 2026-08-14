// IEEE 1800-2017 8.21: pure virtual methods require a virtual class. Keep two
// declarations so the regression also pins one diagnostic per illegal method.
class concrete_c;
  pure virtual task first;
  pure virtual task second(int value);
endclass

module test;
  concrete_c item;
endmodule
