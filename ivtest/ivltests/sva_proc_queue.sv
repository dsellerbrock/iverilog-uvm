// IEEE 1800-2023 16.14.6: a procedural concurrent assertion is not checked
// on every clock. Reaching it queues a pending instance on the process; the
// instance matures in the Observed region and starts one attempt at its
// leading clock, in that time step if the clock occurred, else at the next.
// Edges are at 5, 15, ..., 75.
//
// The a6 and a7 lines follow the user ruling of 2026-11-10 (20.11 does not
// say what Off or Kill does to an instance that matured but still waits for
// its clock): no attempt starts and the instance is discarded; a pending
// instance that matures while Off is discarded at its clock the same way.
module sva_proc_queue;
  logic clk = 0, f = 0, en = 0, trig = 0, cancel = 0;
  always #5 clk = ~clk;
  string log1 = "", log2 = "";
  int n3 = 0, n4 = 0, n5 = 0, n6 = 0, n7 = 0;

  // A: only the edge whose procedure reaches the assertion checks it.
  always @(posedge clk) begin
    if (en) a1: assert property (f) else log1 = {log1, $sformatf(" %0t", $time)};
  end
  initial begin #20 en = 1; #10 en = 0; end

  // B: always reached: one attempt per edge, from the first edge on.
  always @(posedge clk) begin
    a2: assert property (f) else log2 = {log2, $sformatf(" %0t", $time)};
  end

  // C: issue #1195. `disable a3' right after queuing clears the instance.
  always @(posedge trig) begin
    a3: assert property (@(posedge clk) 1'b0) else n3++;
    if (cancel) disable a3;
  end
  initial begin #1 cancel = 1; trig = 1; #0 trig = 0; end

  // D: an initial procedure queues once: one attempt, at the first edge.
  initial a4: assert property (@(posedge clk) f) else n4++;

  // E: queued at 32, matures then, starts at the edge at 35.
  initial begin #32 a5: assert property (@(posedge clk) f) else n5++; end

  // F: queued and matured at 42, $assertoff at 43, its edge at 45.
  initial begin #42 a6: assert property (@(posedge clk) f) else n6++; end
  initial begin #43 $assertoff(0, a6); end

  // G: queued and matured at 52, $assertkill at 53, its edge at 55.
  initial begin #52 a7: assert property (@(posedge clk) f) else n7++; end
  initial begin #53 $assertkill(0, a7); end

  initial begin
    #80;
    $display("a1 (if en, en only at 25):%s", log1);
    $display("a2 (every edge):%s", log2);
    $display("a3 (disabled while pending): %0d", n3);
    $display("a4 (initial): %0d", n4);
    $display("a5 (queued between edges): %0d", n5);
    $display("a6 (matured, then Off before its edge): %0d", n6);
    $display("a7 (matured, then Kill before its edge): %0d", n7);
    $finish;
  end
endmodule
