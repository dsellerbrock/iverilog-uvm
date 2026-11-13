`timescale 1ns/1ns
module issue2831_leaf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule
module top;
  reg a = 0;
  wire y;
  issue2831_leaf u(a, y);
  integer fd, got;
  reg [255:0] line, first, second;
  initial begin
    // Start from a known empty file so stale output cannot satisfy this test.
    fd = $fopen("work/issue2831.log", "w");
    if (fd) $fclose(fd);
    $sdf_annotate("ivltests/issue2831_sdf_log.sdf", top, , "work/issue2831.log");
    fd = $fopen("work/issue2831.log", "r");
    if (!fd) $display("FAILED: no SDF log");
    else begin
      line = 0;
      got = $fgets(line, fd);
      if (got == 0) $display("FAILED: empty SDF log");
      else begin
        got = $sscanf(line, "%s %s", first, second);
        if (second != "IOPATH")
          $display("FAILED: bad SDF log: %0s", line);
        else $display("PASSED");
      end
      $fclose(fd);
    end
    #1 $finish;
  end
endmodule
