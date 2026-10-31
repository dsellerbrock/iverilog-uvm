module issue768_proc_continuous_rhs;
  logic a, b, c, assigned, forced;

  initial begin
    a = 0;
    b = 0;
    c = 0;
    assign assigned = a & b & c;
    a = 1;
    b = 1;
    c = 1;
    #1;
    if (assigned !== 1'b1)
      $fatal(1, "assign failed to evaluate initial RHS: %b", assigned);

    b = 0;
    #1;
    if (assigned !== 1'b0)
      $fatal(1, "assign failed to reevaluate multi-operand RHS: %b", assigned);

    force forced = a | b | c;
    #1;
    if (forced !== 1'b1)
      $fatal(1, "force failed to evaluate initial RHS: %b", forced);

    a = 0;
    c = 0;
    #1;
    if (forced !== 1'b0)
      $fatal(1, "force failed to reevaluate multi-operand RHS: %b", forced);

    release forced;
    deassign assigned;
    $display("ISSUE768_PROC_CONTINUOUS_RHS_PASSED");
    $display("PASSED");
  end
endmodule
