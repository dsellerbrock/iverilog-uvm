`timescale 1ns/1ps

module sdf_increment;
  reg a = 0;
  wire same_y, multi_y;
  realtime edge_start;
  reg checking = 0;

  sdf_increment_cell same(same_y, a);
  sdf_increment_cell multi(multi_y, a);

  always @(same_y) if (checking) begin
    if (($realtime - edge_start) != (a ? 5 : 7))
      $fatal(1, "same-file SDF delay was %0f, expected %0d",
             $realtime - edge_start, a ? 5 : 7);
  end

  always @(multi_y) if (checking) begin
    if (($realtime - edge_start) != (a ? 5 : 7))
      $fatal(1, "multi-file SDF delay was %0f, expected %0d",
             $realtime - edge_start, a ? 5 : 7);
  end

  initial begin
    $sdf_annotate("ivltests/sdf_increment_same.sdf", sdf_increment);
    $sdf_annotate("ivltests/sdf_increment_abs.sdf", sdf_increment);
    $sdf_annotate("ivltests/sdf_increment_inc.sdf", sdf_increment);

    #10;
    checking = 1;
    edge_start = $realtime;
    a = 1;
    #20;
    edge_start = $realtime;
    a = 0;
    #10;
    $display("PASS: SDF INCREMENT accumulates in file and annotation order");
    $finish;
  end
endmodule

module sdf_increment_cell(output y, input a);
  buf (y, a);
  specify
    (a => y) = (0, 0);
  endspecify
endmodule
