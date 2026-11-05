class inside_whole_k;
  rand bit [15:0] k;
  rand bit [31:0] r;
  constraint c { k inside {[16'h4000:16'h40ff]}; r[23:8] == k; }
endclass

class inside_whole_r;
  rand bit [15:0] k;
  rand bit [31:0] r;
  constraint c { r inside {[32'h0040_0000:32'h00ff_ffff]}; r[23:8] == k; }
endclass

class inside_part_select;
  rand bit [15:0] k;
  rand bit [31:0] r;
  constraint c { r[23:8] inside {[16'h4000:16'h40ff]}; r[23:8] == k; }
endclass

module main;
  inside_whole_k whole_k;
  inside_whole_r whole_r;
  inside_part_select part_select;

  initial begin
    whole_k = new;
    if (whole_k.randomize() !== 1
        || whole_k.k < 16'h4000 || whole_k.k > 16'h40ff
        || whole_k.r[23:8] !== whole_k.k)
      $fatal(1, "whole-k randomization failed");
    $display("whole-k PASS");

    whole_r = new;
    if (whole_r.randomize() !== 1
        || whole_r.r < 32'h0040_0000 || whole_r.r > 32'h00ff_ffff
        || whole_r.r[23:8] !== whole_r.k)
      $fatal(1, "whole-r randomization failed");
    $display("whole-r PASS");

    part_select = new;
    if (part_select.randomize() !== 1
        || part_select.r[23:8] < 16'h4000
        || part_select.r[23:8] > 16'h40ff
        || part_select.r[23:8] !== part_select.k)
      $fatal(1, "part-select randomization failed");
    $display("part-select PASS");
  end
endmodule
