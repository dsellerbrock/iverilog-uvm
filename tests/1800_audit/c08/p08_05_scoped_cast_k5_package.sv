package pkg;
  typedef bit [2:0] T;
endpackage
module top;
  int x = 9;
  initial begin
    if (pkg::T'(x) !== 3'b001) $fatal(1, "K5 expected 1");
    $display("PASS K5 value=%0d", pkg::T'(x));
  end
endmodule
