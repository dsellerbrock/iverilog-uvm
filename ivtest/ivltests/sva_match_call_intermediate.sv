// IEEE 1800-2023 16.11: "All subroutine calls attached to a sequence are
// executed at every end point of the sequence. For each end point, the
// attached calls are executed in the order they appear in the list." A call
// attached to an inner step runs where that step matches, whether or not the
// whole sequence matches later. Edges at 5, 15, ..., 55; start is 1 at 15,
// finish at 25, mid at 15 and 25; x is 1 at 15 and 2 at 25 (sampled).
// Each call appends "time:code" to its assertion's log, printed at the end.
module sva_match_call_intermediate;
  logic clk = 0;
  always #5 clk = ~clk;
  logic start = 0, finish = 0, mid = 0;
  int x = 0;
  always @(posedge clk) x <= x + 1;
  string l1 = "", l2 = "", l3 = "", l4 = "", l5 = "", l6 = "";
  int p2 = 0;
  task automatic t1(input int c); l1 = {l1, $sformatf(" %0t:%0d", $time, c)}; endtask
  task automatic t2(input int c); l2 = {l2, $sformatf(" %0t:%0d", $time, c)}; endtask
  task automatic t3(input int c); l3 = {l3, $sformatf(" %0t:%0d", $time, c)}; endtask
  task automatic t4(input int c); l4 = {l4, $sformatf(" %0t:%0d", $time, c)}; endtask
  task automatic t5(input int c); l5 = {l5, $sformatf(" %0t:%0d", $time, c)}; endtask
  task automatic t6(input int c); l6 = {l6, $sformatf(" %0t:%0d", $time, c)}; endtask

  // c0: issue #1381's repro.
  sequence two_steps;
    @(posedge clk) (start, $display("first-step-match")) ##1 finish;
  endsequence
  c0: assert property (two_steps) else ;
  // c1: the same shape through a task.
  c1: assert property (@(posedge clk) (start, t1(1)) ##1 finish) else ;
  // c2: the call runs at 15 although that attempt fails at 25.
  c2: assert property (@(posedge clk) (start, t2(1)) ##1 !finish) p2++; else ;
  // c3: a local variable assigned before the call, in the first and the
  // last step; attempts at 15 (v = 1) and 25 (v = 2).
  sequence s3;
    int v;
    @(posedge clk) (mid, v = x, t3(v)) ##2 (1'b1, t3(v + 100));
  endsequence
  c3: assert property (s3) else ;
  // c4: two calls on one inner step run in list order.
  c4: assert property (@(posedge clk) (start, t4(1), t4(2)) ##1 1'b1) else ;
  // c5, c6: "Actual argument expressions that are passed by value use
  // sampled values of the underlying variables and are consistent with the
  // variable values used to evaluate the sequence match": at 25, $past(x, 1)
  // and a local assigned x at 15 are both 1 (they read 0 before).
  c5: assert property (@(posedge clk) start ##1 (1'b1, t5($past(x, 1)))) else ;
  sequence s6;
    int v;
    @(posedge clk) (start, v = x) ##1 (1'b1, t6(v));
  endsequence
  c6: assert property (s6) else ;

  initial begin
    #10 start = 1; mid = 1;
    #10 start = 0; finish = 1;
    #10 finish = 0; mid = 0;
    #30;
    $display("l1%s", l1);
    $display("l2%s passes %0d", l2, p2);
    $display("l3%s", l3);
    $display("l4%s", l4);
    $display("l5%s", l5);
    $display("l6%s", l6);
    $finish;
  end
endmodule
