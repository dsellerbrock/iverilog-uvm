// IEEE 1800 §40.2.2, §40.3.2.1-3: source statement coverage.
module stmt_cov_leaf(input bit enable);
  int x;
  initial begin x=1; if (enable) x=2; end
endmodule

module stmt_cov_delay(input bit clk);
  bit x, y;
  always @(posedge clk) begin : work
    #2 x = ~x; y <= ~y;
  end
endmodule

module stmt_cov_else(input bit clk, enable);
  bit x;
  always @(posedge clk)
    if (enable) begin end
    else x <= 1;
endmodule

module stmt_cov_unavailable;
  bit x;
  initial begin
    x = 1;
    repeat (2) x = !x;
  end
endmodule

module stmt_cov_nested #(parameter int DEPTH = 1);
  bit x;
  initial x = 1;
  if (DEPTH > 0) begin : gen_child
    stmt_cov_nested #(DEPTH - 1) child();
  end
endmodule

module stmt_cov_tree(input bit clk, enable);
  if (1) begin : gen_leaves
    stmt_cov_leaf a(1'b1), b(1'b0);
    stmt_cov_delay d1(clk), d2(clk);
    stmt_cov_else conditional(clk, enable);
    stmt_cov_nested nested();
  end
  for (genvar i = 0; i < 2; ++i) begin : gen_points
    bit x;
    initial x = 1;
  end
  stmt_cov_unavailable uninstrumented();
endmodule

module stmt_cov_other_root;
  bit x;
  initial begin x = 1; end
endmodule

`define CONTROL(op, scope, target) $coverage_control(op, `SV_COV_STATEMENT, scope, target)
`define MAXIMUM(scope, target) $coverage_get_max(`SV_COV_STATEMENT, scope, target)
`define HITS(scope, target) $coverage_get(`SV_COV_STATEMENT, scope, target)

module issue3934;
  bit clk, enable;
  stmt_cov_tree dut(clk, enable);

  task automatic check(input string label, input int got, expected);
    if (got !== expected)
      $fatal(1, "%s: expected %0d, got %0d", label, expected, got);
  endtask

  initial begin
    #1;
    check("instance CHECK", `CONTROL(`SV_COV_CHECK, `SV_COV_MODULE, dut.gen_leaves.a), `SV_COV_OK);
    check("a maximum", `MAXIMUM(`SV_COV_MODULE, dut.gen_leaves.a), 4);
    check("b maximum", `MAXIMUM(`SV_COV_MODULE, dut.gen_leaves.b), 4);
    check("a hits", `HITS(`SV_COV_MODULE, dut.gen_leaves.a), 4);
    check("b hits", `HITS(`SV_COV_MODULE, dut.gen_leaves.b), 3);
    check("definition below generate", `MAXIMUM(`SV_COV_MODULE, "stmt_cov_leaf"), 8);
    check("definition hits", `HITS(`SV_COV_MODULE, "stmt_cov_leaf"), 7);
    check("overlapping definition hierarchy", `MAXIMUM(`SV_COV_HIER, "stmt_cov_nested"), 2);
    check("overlapping definition hits", `HITS(`SV_COV_HIER, "stmt_cov_nested"), 2);
    check("generate iterations", `MAXIMUM(`SV_COV_MODULE, dut), 2);
    check("generate hits", `HITS(`SV_COV_MODULE, dut), 2);
    check("mixed instance CHECK", `CONTROL(`SV_COV_CHECK, `SV_COV_HIER, dut), `SV_COV_PARTIAL);
    check("mixed definition START", `CONTROL(`SV_COV_START, `SV_COV_HIER, "stmt_cov_tree"), `SV_COV_PARTIAL);
    check("mixed maximum", `MAXIMUM(`SV_COV_HIER, dut), 26);
    check("mixed hits", `HITS(`SV_COV_HIER, "stmt_cov_tree"), 14);
    check("unavailable CHECK", `CONTROL(`SV_COV_CHECK, `SV_COV_MODULE, dut.uninstrumented), `SV_COV_NOCOV);
    check("unavailable START", `CONTROL(`SV_COV_START, `SV_COV_MODULE, "stmt_cov_unavailable"), `SV_COV_NOCOV);
    check("unavailable maximum", `MAXIMUM(`SV_COV_MODULE, dut.uninstrumented), `SV_COV_NOCOV);
    check("unavailable RESET", `CONTROL(`SV_COV_RESET, `SV_COV_MODULE, dut.uninstrumented), `SV_COV_OK);
    check("invalid definition", `HITS(`SV_COV_HIER, "no_such_definition"), `SV_COV_ERROR);
    check("root CHECK", `CONTROL(`SV_COV_CHECK, `SV_COV_HIER, $root), `SV_COV_PARTIAL);
    check("root maximum", `MAXIMUM(`SV_COV_HIER, $root), 28);
    check("root hits", `HITS(`SV_COV_HIER, $root), 16);

    check("same-line assignments", `MAXIMUM(`SV_COV_MODULE, dut.gen_leaves.d1), 5);
    check("initial event wait", `HITS(`SV_COV_MODULE, dut.gen_leaves.d1), 1);
    check("STOP", `CONTROL(`SV_COV_STOP, `SV_COV_MODULE, dut.gen_leaves.d1), `SV_COV_OK);
    check("repeated STOP", `CONTROL(`SV_COV_STOP, `SV_COV_MODULE, dut.gen_leaves.d1), `SV_COV_OK);
    clk = 1;
    #1;
    check("stopped hits", `HITS(`SV_COV_MODULE, dut.gen_leaves.d1), 1);
    check("before delay expires", `HITS(`SV_COV_MODULE, dut.gen_leaves.d2), 3);
    check("untaken empty block", `HITS(`SV_COV_MODULE, dut.gen_leaves.conditional), 3);
    #2;
    check("after delay and NBA", `HITS(`SV_COV_MODULE, dut.gen_leaves.d2), 5);
    check("blocking and NBA effects", {dut.gen_leaves.d2.x, dut.gen_leaves.d2.y}, 3);
    check("RESET stopped", `CONTROL(`SV_COV_RESET, `SV_COV_MODULE, dut.gen_leaves.d1), `SV_COV_OK);
    check("CHECK while stopped", `CONTROL(`SV_COV_CHECK, `SV_COV_MODULE, dut.gen_leaves.d1), `SV_COV_OK);
    check("maximum after RESET", `MAXIMUM(`SV_COV_MODULE, dut.gen_leaves.d1), 5);
    check("sibling isolation", `HITS(`SV_COV_MODULE, dut.gen_leaves.d2), 5);

    clk = 0;
    enable = 1;
    #1 clk = 1;
    #3;
    check("RESET preserves stopped state", `HITS(`SV_COV_MODULE, dut.gen_leaves.d1), 0);
    check("repeat does not increase hits", `HITS(`SV_COV_MODULE, dut.gen_leaves.d2), 5);
    check("taken empty block", `HITS(`SV_COV_MODULE, dut.gen_leaves.conditional), 4);
    check("START after RESET", `CONTROL(`SV_COV_START, `SV_COV_MODULE, dut.gen_leaves.d1), `SV_COV_OK);
    check("RESET while collecting", `CONTROL(`SV_COV_RESET, `SV_COV_MODULE, dut.gen_leaves.d2), `SV_COV_OK);
    check("combined reset hits", `HITS(`SV_COV_MODULE, "stmt_cov_delay"), 0);

    clk = 0;
    #1 clk = 1;
    #3;
    check("restarted hits", `HITS(`SV_COV_MODULE, dut.gen_leaves.d1), 5);
    check("RESET preserves collecting state", `HITS(`SV_COV_MODULE, dut.gen_leaves.d2), 5);
    check("definition maximum stays fixed", `MAXIMUM(`SV_COV_MODULE, "stmt_cov_delay"), 10);
    check("final root hits", `HITS(`SV_COV_HIER, $root), 27);
    check("save unavailable", $coverage_save(`SV_COV_STATEMENT, "snapshot"), `SV_COV_ERROR);
    check("merge unavailable", $coverage_merge(`SV_COV_STATEMENT, "snapshot"), `SV_COV_ERROR);
    $display("PASSED");
    $finish;
  end
endmodule

`undef CONTROL
`undef MAXIMUM
`undef HITS
