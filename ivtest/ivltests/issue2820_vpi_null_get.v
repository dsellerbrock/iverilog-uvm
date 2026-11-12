module top;
  logic [7:0] v = 8'h5a;
  real r = 1.5;
  initial #1 begin
    $probe;
    $display("DONE");
  end
endmodule
