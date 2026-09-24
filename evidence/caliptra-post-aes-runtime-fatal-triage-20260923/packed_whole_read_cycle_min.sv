module packed_whole_read_cycle_min;
  logic [2:0] dependent;
  assign dependent[0] = 1'b1;
  assign dependent[1] = |dependent;
  initial begin
    #1;
    $display("whole_read=%b", dependent);
    if (dependent !== 3'bz11) $fatal(1, "whole-vector feedback lost");
    $display("PASS whole-vector feedback");
  end
endmodule
