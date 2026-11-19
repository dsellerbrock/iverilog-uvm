package other;
  class Target; endclass
endpackage

module top;
  class Target; endclass
  typedef Target DefaultAlias;
  typedef string Text;
  typedef int Pair [2:3];

  class Box #(int N = 1 + 2, type T = DefaultAlias);
    parameter int B = N + 2;
    parameter type BodyType = int;
    parameter Target NullValue = null;
    typedef int Scalar;
    typedef other::Target ClassAlias;
    class Nested; endclass
  endclass

  Box#(7, Text) first;
  Box#(9, Pair) second;

  class Required #(int N, type T);
  endclass
  Required#(13, shortint) supplied;
endmodule
