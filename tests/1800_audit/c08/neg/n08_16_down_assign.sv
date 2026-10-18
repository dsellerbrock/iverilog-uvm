class A; endclass
class B extends A; endclass
module top;
  A a;
  B b;
  initial b = a;
endmodule
