module top;
  logic [7:0] v = 8'h5a;

  initial #1 begin
    $probe;
    $display("DONE");
    $display("PASSED");
  end
endmodule
