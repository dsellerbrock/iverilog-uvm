// A static named block that nothing disables may run in its enclosing
// thread instead of a forked child. A begin-end block is not a process
// (IEEE 1800-2017/2023 9.3.1, 9.7), so the block must still behave exactly
// as before: its scope name, static locals, disable, break, return, and
// the change events it produces are all unchanged.
module test;
  logic clk = 0;
  logic [7:0] a = 0, b = 0, c = 0;
  logic [7:0] seen = 0;
  integer changes = 0;
  integer evals = 0;
  string where;
  logic p_same = 0;
  integer failed = 0;

  // Combinational logic in a named block, with a nested named block.
  always @* begin : comb_outer
    b = a + 8'd1;
    begin : comb_inner
      c = b ^ 8'h5a;
    end
  end

  // A static local in a named block keeps its value between runs.
  always @(posedge clk) begin : counter
    integer count;
    if (count === 'x) count = 0;
    count = count + 1;
    evals = count;
  end

  // %m in an expression reports the block's scope.
  always @(posedge clk) begin : named_scope
    where = $sformatf("%m");
  end

  // Intermediate blocking values produce change events as before.
  logic [7:0] glitch = 0;
  always @(posedge clk) begin : glitchy
    glitch = 8'd1;
    glitch = 8'd0;
  end
  always @(glitch) changes = changes + 1;

  // A named block that is disabled from inside must stop there.
  always @(posedge clk) begin : disabled_blk
    seen = seen + 1;
    if (seen[0]) disable disabled_blk;
    seen = seen + 8'd10;
  end

  // break out of a loop inside a named block.
  integer broke = 0;
  always @(posedge clk) begin : loop_blk
    for (int i = 0; i < 10; i++) begin
      if (i == 3) break;
      broke = i;
    end
  end

  // return from a function inside its own named block.
  function automatic integer first_set(input logic [7:0] v);
    begin : search
      for (int i = 0; i < 8; i++)
        if (v[i]) return i;
    end
    return -1;
  endfunction

  // A begin-end block is not a process.
  initial begin : self_check
    process outer;
    outer = process::self();
    begin : inner_self
      p_same = (process::self() == outer);
    end
  end

  task automatic expect_eq(input string what, input integer got, input integer exp);
    if (got !== exp) begin
      $display("FAILED: %s got %0d expected %0d", what, got, exp);
      failed++;
    end
  endtask

  initial begin
    #1 a = 8'h10;
    #1 expect_eq("comb b", b, 8'h11);
    expect_eq("comb c", c, 8'h11 ^ 8'h5a);
    repeat (4) begin #5 clk = 1; #5 clk = 0; end
    expect_eq("static local", evals, 4);
    if (where != "test.named_scope") begin
      $display("FAILED: %%m gave %s", where);
      failed++;
    end
    // Each edge makes glitch 0->1->0 in one run of the block. The waiter
    // wakes on 0->1 but is not waiting again until it has run, so it
    // counts one change per edge.
    expect_eq("glitch changes", changes, 4);
    // seen: odd values are disabled before +10. 0->1 (disabled), 1->2->12,
    // 12->13 (disabled), 13->14->24.
    expect_eq("disable", seen, 24);
    expect_eq("break", broke, 2);
    expect_eq("return", first_set(8'b0010_0100), 2);
    expect_eq("return none", first_set(8'b0), -1);
    expect_eq("process::self", p_same, 1);
    if (failed == 0) $display("PASSED");
    $finish;
  end
endmodule
