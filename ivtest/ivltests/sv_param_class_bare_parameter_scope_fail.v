module test;
  class box #(int VALUE = 1);
    parameter int DERIVED = VALUE + 2;
  endclass

  initial $display("FAILED %0d", box::DERIVED);
endmodule
