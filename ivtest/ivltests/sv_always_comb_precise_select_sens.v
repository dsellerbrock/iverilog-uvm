`begin_keywords "1800-2012"

module main;
  logic [3:0] source;
  logic       observed;
  integer     evaluations;
  integer     baseline;

  // evaluations is written by this process and therefore excluded from its
  // implicit sensitivity set. It makes otherwise harmless extra evaluations
  // observable without introducing another writer.
  always_comb begin
    evaluations = (evaluations === 32'bx) ? 1 : evaluations + 1;
    observed = source[1];
  end

  task automatic fail(input string label);
    $display("FAILED -- %s source=%b observed=%b evaluations=%0d",
             label, source, observed, evaluations);
    $finish;
  endtask

  initial begin
    source = 4'b0000;
    #1;
    if (observed !== 1'b0 || evaluations < 1)
      fail("time-zero evaluation");
    baseline = evaluations;

    source[3] = 1'b1;
    #1;
    if (observed !== 1'b0 || evaluations !== baseline)
      fail("unselected bit triggered process");

    source[1] = 1'b1;
    #1;
    if (observed !== 1'b1 || evaluations !== baseline + 1)
      fail("selected bit did not trigger process");
    baseline = evaluations;

    source[0] = 1'b1;
    #1;
    if (observed !== 1'b1 || evaluations !== baseline)
      fail("second unselected bit triggered process");

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
