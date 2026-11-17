module tb;
  logic d = 1;
  wire (strong1, pull0) logic #5 q = d;
  initial begin
    #10;
    if (q !== 1'b1) $fatal(1, "incorrect net value");
    $display("PASS");
  end
endmodule
