class Outer;
  interface class Nested;
    pure virtual function void f();
  endclass
endclass

module top;
  initial $display("nested interface class accepted");
endmodule
