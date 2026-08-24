// IEEE 1800-2017 16.14.6: an assertion failure runs the action block
// the user wrote. A strong eventuality that remains pending can be decided
// only at end of simulation, so the synthesized final process needs an exact
// copy of that action -- including any package qualification on a void
// function call.
//
// OpenTitan's TL-UL checker uses this exact tree-antecedent shape with
// `uvm_pkg::uvm_report_error(...)`. The old action copier retained only the
// final identifier, turning action_pkg::record_failure into an unresolved
// record_failure call. Elaboration warned and silently replaced the only
// end-of-simulation report with a no-op.

package action_pkg;
  int calls;

  function void record_failure(string id);
    calls++;
    $display("PACKAGE ACTION %s", id);
  endfunction
endpackage

module main;
  logic clk = 0;
  logic trigger = 0;
  logic qualifier = 0;
  logic done = 0;

  always #5 clk = ~clk;

  tree_eventual:
    assert property (@(posedge clk) trigger and qualifier |=>
                     s_eventually(done))
    else action_pkg::record_failure("tree_eventual");

  initial begin
    @(negedge clk) begin
      trigger = 1;
      qualifier = 1;
    end
    @(negedge clk) begin
      trigger = 0;
      qualifier = 0;
    end
    repeat (3) @(negedge clk);
    $finish(0);
  end

  final begin
    if (action_pkg::calls == 1)
      $display("PASSED");
    else
      $display("FAILED -- package action calls=%0d (expected 1)",
               action_pkg::calls);
  end
endmodule
