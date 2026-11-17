module tb;
  reg [3:0] a, b;
  initial begin
    a = 4'b10xz; b = 4'b1100;
    if ((a ~& b) !== 4'b0111) $fatal(1, "binary NAND failed");
    if ((a ~| b) !== 4'b00xx) $fatal(1, "binary NOR failed");
    $display("PASS");
  end
endmodule
