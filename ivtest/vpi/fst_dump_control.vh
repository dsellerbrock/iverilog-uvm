// Check the FST dumper's control tasks (IEEE 1800-2023 21.7.1): $dumpvars
// levels and scope/variable selection, $dumpoff (every variable dumped as x),
// $dumpon (current values), $dumpall (a checkpoint of every variable),
// $dumpflush, and a $dumplimit given before the dump file is opened.
module leaf;
  logic [3:0] l = 0;
  always #3 l = l + 1;
endmodule

module mid;
  logic m = 0;
  leaf deep();
endmodule

module top;
  logic [1:0] a = 0;
  real r = 0.5;
  mid inner();
  mid other();
  initial begin
    $fst_text("fst_dump_control.fst");
    $dumplimit(1000000);
    $dumpfile("fst_dump_control.fst");
      // top's own variables and inner (one level), and one variable of other.
    $dumpvars(1, top);
    $dumpvars(2, inner);
    $dumpvars(0, other.deep.l);
    #2 a = 1;
    #2 $dumpoff;
    a = 2; r = 1.25;
    #3 a = 3;
    #3 $dumpon;
    #2 $dumpall;
    #1 $dumpflush;
    a = 0;
    #1 $finish(0);
  end
endmodule
