module packed_whole_read_covered_min;
  logic [1:0] dependent;
  assign dependent[0] = 1'b1;
  assign dependent[1] = |dependent;
  initial begin
    #1;
    $display("covered_whole_read=%b", dependent);
    if (dependent !== 2'b11) $fatal(1, "covered whole-vector feedback lost");
    $display("PASS covered whole-vector feedback");
  end
endmodule
