// R2: a concurrent assertion ACTION block runs in the REACTIVE region
// (IEEE 1800-2017 4.4.2.5), one region after the Observed region the
// verdict is computed in.
//
// Evaluation moving to Observed (M6B-4) put the verdict after the design's
// nonblocking updates. The action ran there too, one region early: testbench
// code woken by an assertion failure then ran ahead of the program-block
// processes 4.4.2.5 puts in the same region set.
//
// The discriminator is execution ORDER against a program-block process at
// the same clock edge. A program process is queued into Reactive when the
// edge is detected in Active, so it is already in the queue by the time the
// Observed region runs; the action, deferred from Observed, lands behind it.
// With the action still in Observed the order is reversed -- against the
// pre-fix compiler this printed `prog=2 act=1'.
//
// The settled-state property of the Observed region must survive the move:
// the action still reads the post-NBA value of `v', and the action must run
// exactly once per failing edge.
module main;

  reg clk = 0;
  reg b = 0;               // operand: always false, so every edge fails
  reg [7:0] v = 8'd0;      // updated by NBA at the same edge

  integer seq = 0;         // slot-order counter, shared with the program
  integer prog_stamp = -1; // seq position of the program process
  integer act_stamp = -1;  // seq position of the assertion action
  integer act_runs = 0;
  integer act_saw_v = -1;

  always #5 clk = ~clk;
  always @(posedge clk) v <= v + 1;

  assert property (@(posedge clk) b)
    else begin
      seq = seq + 1;
      if (act_stamp < 0) act_stamp = seq;
      act_runs = act_runs + 1;
      act_saw_v = v;
    end

endmodule

program obs;

  initial begin
    @(posedge main.clk);              // resumes in Reactive at t=5
    main.seq = main.seq + 1;
    if (main.prog_stamp < 0) main.prog_stamp = main.seq;

    #1;                               // let the whole t=5 slot finish

    if (main.act_stamp < 0)
      $display("FAILED -- the action never ran; the test itself is broken");
    else if (main.prog_stamp != 1 || main.act_stamp != 2)
      $display("FAILED -- prog=%0d act=%0d; the action did not run in the Reactive region behind the program process",
               main.prog_stamp, main.act_stamp);
    else if (main.act_runs != 1)
      $display("FAILED -- the action ran %0d times for one failing edge, expected 1",
               main.act_runs);
    else if (main.act_saw_v != 1)
      $display("FAILED -- the action read v=%0d, expected the settled 1; it is running before the nonblocking updates",
               main.act_saw_v);
    else
      $display("PASSED");
  end

endprogram
