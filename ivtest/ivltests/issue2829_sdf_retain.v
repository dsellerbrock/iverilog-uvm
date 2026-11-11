`timescale 1ns/1ns

module issue2829_retain_leaf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue2829_retain_cond(input a, input mode, output y);
  assign y = a;
  specify if (mode == 1'b1) (a => y) = 1; endspecify
endmodule

module issue2829_retain_else(input a, output y);
  assign y = a;
  specify ifnone (a => y) = 1; endspecify
endmodule

module issue2829_sdf_retain;
  reg a = 0;
  wire y, yc, ye;
  issue2829_retain_leaf u(a, y);
  issue2829_retain_cond c(a, 1'b1, yc);
  issue2829_retain_else e(a, ye);

  initial begin
    $sdf_annotate("ivltests/issue2829_sdf_retain.sdf", issue2829_sdf_retain);
    #6;
    if (y !== 0 || yc !== 0 || ye !== 0)
      $fatal(1, "RETAIN IOPATHs did not apply the 5 ns initial delay");
    #4 a = 1;
    #2;
    if (y !== 0 || yc !== 0 || ye !== 0)
      $fatal(1, "RETAIN IOPATHs did not delay the transition by 5 ns");
    #3;
    if (y !== 1 || yc !== 1 || ye !== 1)
      $fatal(1, "RETAIN IOPATHs did not apply the 5 ns transition delay");
    $display("PASSED");
    $finish;
  end
endmodule
