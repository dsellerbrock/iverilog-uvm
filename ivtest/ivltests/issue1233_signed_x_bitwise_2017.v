module main;
  logic signed [7:0] value = 8'b000x0001;
  logic signed [7:0] result;

  initial begin
    result = value & 8'shff;
    if (result !== 8'bxxxxxxxx)
      $fatal(1, "signed bitwise result was %b", result);
    $display("PASSED");
    $finish;
  end
endmodule
