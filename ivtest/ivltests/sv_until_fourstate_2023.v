// Four-state boundary for IEEE 1800-2017/2023 16.12.12.
// An X/Z operand is not a true p hold or q discharge.
module until_implication_fourstate;
  bit clk = 0;
  logic [1:0] p = 1, q = 0;
  bit px = 0, pz = 0, qx = 0, qz = 0, p10 = 0, p1x = 0, q10 = 0, q1x = 0;
  int fpx = 0, fpz = 0, fqx = 0, fqz = 0, fp10 = 0, fp1x = 0, fq10 = 0, fq1x = 0;
  always #5 clk = ~clk;

  assert property (@(posedge clk) px |=> p until q) else fpx++;
  assert property (@(posedge clk) pz |=> p until q) else fpz++;
  assert property (@(posedge clk) qx |=> p until q) else fqx++;
  assert property (@(posedge clk) qz |=> p until q) else fqz++;
  assert property (@(posedge clk) p10 |=> p until q) else fp10++;
  assert property (@(posedge clk) p1x |=> p until q) else fp1x++;
  assert property (@(posedge clk) q10 |=> p until q) else fq10++;
  assert property (@(posedge clk) q1x |=> p until q) else fq1x++;

  `define PULSE(sig) @(negedge clk) sig = 1; @(negedge clk) sig = 0;
  initial begin
    // p must be true before q: X and Z both fail immediately.
    p = 'x; q = 0; `PULSE(px) repeat (2) @(negedge clk);
    p = 'z; q = 0; `PULSE(pz) repeat (2) @(negedge clk);

    // q is not a discharge while X/Z. The subsequent low p, low q tick
    // must still fail the outstanding obligation.
    p = 1; q = 'x; `PULSE(qx) @(negedge clk) p = 0; q = 0;
    repeat (2) @(negedge clk);
    p = 1; q = 'z; `PULSE(qz) @(negedge clk) p = 0; q = 0;
    repeat (2) @(negedge clk);

    // A known nonzero bit makes 2'b10 and 2'b1x true in a Boolean context.
    p = 2'b10; q = 0; `PULSE(p10) @(negedge clk) q = 1;
    repeat (2) @(negedge clk);
    p = 2'b1x; q = 0; `PULSE(p1x) @(negedge clk) q = 1;
    repeat (2) @(negedge clk);
    // The same truth conversion discharges q even while p is low.
    p = 0; q = 2'b10; `PULSE(q10) repeat (2) @(negedge clk);
    p = 0; q = 2'b1x; `PULSE(q1x) repeat (2) @(negedge clk);
    $finish(0);
  end

  final begin
    if (fpx != 1 || fpz != 1 || fqx != 1 || fqz != 1 ||
        fp10 != 0 || fp1x != 0 || fq10 != 0 || fq1x != 0)
      $fatal(1, "four-state until px=%0d pz=%0d qx=%0d qz=%0d p10=%0d p1x=%0d q10=%0d q1x=%0d",
             fpx, fpz, fqx, fqz, fp10, fp1x, fq10, fq1x);
    $display("PASS: implication until four-state boundary");
  end
endmodule
