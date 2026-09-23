// IEEE 1800-2017/2023 16.12.7 gives each antecedent match a separate
// consequent; 16.14.1 executes the else action for each failed assertion.
// Two attempts here fail on one sampled edge.
module literal_overlap_failure_count;
  logic clk = 0, start = 0, ready = 0;
  integer failures = 0;

  checked: assert property (@(posedge clk)
      start |=> !ready[*3] ##1 ready)
    ;
  else failures++;

  task automatic tick(input logic s, r);
    start = s;
    ready = r;
    #5 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    tick(1, 0);  // Attempt A.
    tick(1, 0);  // Attempt B; A's first !ready match.
    tick(0, 0);  // A/B continue.
    tick(0, 1);  // Both A and B fail a distinct !ready obligation.
    if (failures != 2) begin
      $display("FAILED: same-edge attempts reported %0d/2 failures", failures);
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
