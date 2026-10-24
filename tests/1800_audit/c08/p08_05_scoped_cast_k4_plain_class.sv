class P;
  typedef bit [2:0] T;
endclass
module top;
  int x = 9;
  initial begin
    if (P::T'(x) !== 3'b001) $fatal(1, "K4 expected 1");
    $display("PASS K4 value=%0d", P::T'(x));
  end
endmodule
