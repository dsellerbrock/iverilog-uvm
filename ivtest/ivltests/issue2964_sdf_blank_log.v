// Issue #2964: an omitted $sdf_annotate log_file argument (IEEE 1800-2023
// 32.7) arrives as a blank string; it must not open a file named " ".
`timescale 1ns/1ns
module issue2964_leaf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule
module top;
  reg a = 0;
  wire y;
  issue2964_leaf u(a, y);
  integer fd;
  initial begin
    fd = $fopen(" ", "r");
    if (fd) begin
      $display("FAILED: a stale file named \" \" exists; remove it and rerun");
      $fclose(fd);
    end else begin
      $sdf_annotate("ivltests/issue2831_sdf_log.sdf", top, , , "MAXIMUM");
      fd = $fopen(" ", "r");
      if (fd) begin
        $display("FAILED: blank log_file argument created a file named \" \"");
        $fclose(fd);
      end else $display("PASSED");
    end
    #1 $finish;
  end
endmodule
