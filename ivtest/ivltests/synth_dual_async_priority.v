`begin_keywords "1800-2012"

module clear_priority_dff (
  input  logic       clk,
  input  logic       reset_n,
  input  logic       aset,
  input  logic [3:0] data,
  output logic [3:0] state
);
  always_ff @(posedge clk, negedge reset_n, posedge aset) begin
    if (!reset_n)
      state <= 4'h0;
    else if (aset)
      state <= 4'ha;
    else
      state <= data;
  end
endmodule

module clear_priority_expr_dff (
  input  logic       clk,
  input  logic       reset_n,
  input  logic       aset,
  input  logic       choose_data,
  input  logic [3:0] data,
  output logic [3:0] state
);
  always_ff @(posedge clk, negedge reset_n, posedge aset) begin
    if (!reset_n)
      state <= 4'h0;
    else if (aset)
      state <= 4'ha;
    else
      // This mux keeps D expression-driven after synthesis. Vlog95 must
      // materialize it before selecting scalar FF bits so Z is preserved.
      state <= choose_data ? data : 4'h6;
  end
endmodule

module set_priority_dff (
  input  logic       clk,
  input  logic       reset_n,
  input  logic       aset,
  input  logic [3:0] data,
  output logic [3:0] state
);
  always_ff @(posedge clk, negedge reset_n, posedge aset) begin
    if (aset)
      state <= 4'h5;
    else if (!reset_n)
      state <= 4'h0;
    else
      state <= data;
  end
endmodule

module mixed_priority_dff (
  input  logic       clk,
  input  logic       reset_n,
  input  logic       aset,
  input  logic [3:0] data,
  output logic [3:0] clear_state,
  output logic [3:0] set_state
);
  // Keep two independently prioritized outputs in one process. This proves
  // synthesis carries priority per generated FF instead of collapsing the
  // process to one global ordering bit.
  always_ff @(posedge clk, negedge reset_n, posedge aset) begin
    if (!reset_n)
      clear_state <= 4'h0;
    else if (aset)
      clear_state <= 4'ha;
    else
      clear_state <= data;

    if (aset)
      set_state <= 4'h5;
    else if (!reset_n)
      set_state <= 4'h0;
    else
      set_state <= data;
  end
endmodule

module clear_priority_dff_n (
  input  logic       clk,
  input  logic       reset_n,
  input  logic       aset,
  input  logic [3:0] data,
  output logic [3:0] state
);
  always_ff @(negedge clk, negedge reset_n, posedge aset) begin
    if (!reset_n)
      state <= 4'h0;
    else if (aset)
      state <= 4'hc;
    else
      state <= data;
  end
endmodule

module set_priority_dff_n (
  input  logic       clk,
  input  logic       reset_n,
  input  logic       aset,
  input  logic [3:0] data,
  output logic [3:0] state
);
  always_ff @(negedge clk, negedge reset_n, posedge aset) begin
    if (aset)
      state <= 4'h6;
    else if (!reset_n)
      state <= 4'h0;
    else
      state <= data;
  end
endmodule

module clear_priority_bitwise_dff (
  input  logic clk,
  input  logic reset_n,
  input  logic aset,
  input  logic data,
  output logic state
);
  // Keep the legal bitwise inversion form: synthesis lowers this condition
  // through a scheduled NOT functor rather than an immediate reduction NOR.
  always_ff @(posedge clk, negedge reset_n, posedge aset) begin
    if (~reset_n)
      state <= 1'b0;
    else if (aset)
      state <= 1'b1;
    else
      state <= data;
  end
endmodule

module main;
  logic       clk;
  logic       reset_n;
  logic       aset;
  logic [3:0] data;
  logic [3:0] clear_priority_state;
  logic [3:0] set_priority_state;
  logic [3:0] clear_priority_expr_state;
  logic [3:0] mixed_clear_priority_state;
  logic [3:0] mixed_set_priority_state;
  logic [3:0] clear_priority_state_n;
  logic [3:0] set_priority_state_n;

  logic       nba_clk;
  logic       nba_reset_n;
  logic       nba_aset;
  logic [3:0] nba_data;
  logic [3:0] nba_clear_priority_state;
  logic [3:0] nba_set_priority_state;
  logic [3:0] nba_clear_priority_state_n;
  logic [3:0] nba_set_priority_state_n;

  logic settle_clk;
  logic settle_reset_n;
  logic settle_aset;
  logic settle_data;
  logic settle_state;
  integer settle_rises;
  logic [3:0] const_posedge_state;
  logic [3:0] const_negedge_state;

  clear_priority_dff clear_priority (
    .clk, .reset_n, .aset, .data, .state(clear_priority_state)
  );
  set_priority_dff set_priority (
    .clk, .reset_n, .aset, .data, .state(set_priority_state)
  );
  clear_priority_expr_dff clear_priority_expr (
    .clk, .reset_n, .aset, .choose_data(1'b1), .data,
    .state(clear_priority_expr_state)
  );
  mixed_priority_dff mixed_priority (
    .clk, .reset_n, .aset, .data,
    .clear_state(mixed_clear_priority_state),
    .set_state(mixed_set_priority_state)
  );
  clear_priority_dff_n clear_priority_n (
    .clk, .reset_n, .aset, .data, .state(clear_priority_state_n)
  );
  set_priority_dff_n set_priority_n (
    .clk, .reset_n, .aset, .data, .state(set_priority_state_n)
  );

  clear_priority_dff nba_clear_priority (
    .clk(nba_clk), .reset_n(nba_reset_n), .aset(nba_aset), .data(nba_data),
    .state(nba_clear_priority_state)
  );
  set_priority_dff nba_set_priority (
    .clk(nba_clk), .reset_n(nba_reset_n), .aset(nba_aset), .data(nba_data),
    .state(nba_set_priority_state)
  );
  clear_priority_dff_n nba_clear_priority_n (
    .clk(nba_clk), .reset_n(nba_reset_n), .aset(nba_aset), .data(nba_data),
    .state(nba_clear_priority_state_n)
  );
  set_priority_dff_n nba_set_priority_n (
    .clk(nba_clk), .reset_n(nba_reset_n), .aset(nba_aset), .data(nba_data),
    .state(nba_set_priority_state_n)
  );
  clear_priority_bitwise_dff settle_dut (
    .clk(settle_clk), .reset_n(settle_reset_n), .aset(settle_aset),
    .data(settle_data), .state(settle_state)
  );
  clear_priority_dff const_posedge_dut (
    .clk(1'b1), .reset_n(1'b1), .aset(1'b0), .data(4'hd),
    .state(const_posedge_state)
  );
  clear_priority_dff_n const_negedge_dut (
    .clk(1'b0), .reset_n(1'b1), .aset(1'b0), .data(4'he),
    .state(const_negedge_state)
  );

  task tick;
    begin
      #1 clk = 1'b1;
      #1 clk = 1'b0;
      #1;
    end
  endtask

  task check;
    input [31:0] code;
    input [3:0] expected_clear_priority;
    input [3:0] expected_set_priority;
    input [3:0] expected_clear_priority_n;
    input [3:0] expected_set_priority_n;
    begin
      if (clear_priority_state !== expected_clear_priority ||
          set_priority_state !== expected_set_priority ||
          clear_priority_expr_state !== expected_clear_priority ||
          mixed_clear_priority_state !== expected_clear_priority ||
          mixed_set_priority_state !== expected_set_priority ||
          clear_priority_state_n !== expected_clear_priority_n ||
          set_priority_state_n !== expected_set_priority_n) begin
        $display("FAILED -- check %0d p=%h/%h expr=%h mixed=%h/%h n=%h/%h expected=%h/%h/%h/%h", code,
                 clear_priority_state, set_priority_state,
                 clear_priority_expr_state,
                 mixed_clear_priority_state, mixed_set_priority_state,
                 clear_priority_state_n, set_priority_state_n,
                 expected_clear_priority, expected_set_priority,
                 expected_clear_priority_n, expected_set_priority_n);
        $finish;
      end
    end
  endtask

  task check_nba;
    input [31:0] code;
    input [3:0] expected_clear_priority;
    input [3:0] expected_set_priority;
    input [3:0] expected_clear_priority_n;
    input [3:0] expected_set_priority_n;
    begin
      if (nba_clear_priority_state !== expected_clear_priority ||
          nba_set_priority_state !== expected_set_priority ||
          nba_clear_priority_state_n !== expected_clear_priority_n ||
          nba_set_priority_state_n !== expected_set_priority_n) begin
        $display("FAILED -- NBA check %0d p=%h/%h n=%h/%h expected=%h/%h/%h/%h", code,
                 nba_clear_priority_state, nba_set_priority_state,
                 nba_clear_priority_state_n, nba_set_priority_state_n,
                 expected_clear_priority, expected_set_priority,
                 expected_clear_priority_n, expected_set_priority_n);
        $finish;
      end
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    reset_n = 1'b1;
    aset = 1'b0;
    data = 4'h3;
    nba_clk = 1'b0;
    nba_reset_n = 1'b1;
    nba_aset = 1'b0;
    nba_data = 4'h3;
    settle_clk = 1'b0;
    settle_reset_n = 1'b1;
    settle_aset = 1'b0;
    settle_data = 1'b0;
    settle_rises = 0;

    tick();
    check(1, 4'h3, 4'h3, 4'h3, 4'h3);

    reset_n = 1'b0;
    #1;
    check(2, 4'h0, 4'h0, 4'h0, 4'h0);

    aset = 1'b1;
    #1;
    check(3, 4'h0, 4'h5, 4'h0, 4'h6);

    // Deasserting a control is absent from the event expression. The state
    // must not spuriously change to the still-active subordinate control.
    aset = 1'b0;
    #1;
    check(4, 4'h0, 4'h5, 4'h0, 4'h6);

    tick();
    check(5, 4'h0, 4'h0, 4'h0, 4'h0);

    reset_n = 1'b1;
    #1;
    check(6, 4'h0, 4'h0, 4'h0, 4'h0);

    data = 4'hc;
    tick();
    check(7, 4'hc, 4'hc, 4'hc, 4'hc);

    aset = 1'b1;
    #1;
    check(8, 4'ha, 4'h5, 4'hc, 4'h6);

    reset_n = 1'b0;
    #1;
    check(9, 4'h0, 4'h5, 4'h0, 4'h6);

    reset_n = 1'b1;
    #1;
    check(10, 4'h0, 4'h5, 4'h0, 4'h6);

    tick();
    check(11, 4'ha, 4'h5, 4'hc, 4'h6);

    aset = 1'b0;
    #1;
    check(12, 4'ha, 4'h5, 4'hc, 4'h6);

    data = 4'h9;
    tick();
    check(13, 4'h9, 4'h9, 4'h9, 4'h9);

    // IEEE edge events include 1->X/Z on an active-low reset and 0->X/Z
    // on an active-high set. An X/Z condition is false in an if statement,
    // so these events reach the data clause rather than forcing a control.
    data = 4'h4;
    reset_n = 1'bx;
    #1;
    check(14, 4'h4, 4'h4, 4'h4, 4'h4);
    reset_n = 1'b1;
    #1;
    check(15, 4'h4, 4'h4, 4'h4, 4'h4);

    data = 4'h7;
    aset = 1'bx;
    #1;
    check(16, 4'h7, 4'h7, 4'h7, 4'h7);
    aset = 1'b0;
    #1;
    check(17, 4'h7, 4'h7, 4'h7, 4'h7);

    data = 4'h2;
    reset_n = 1'bz;
    #1;
    check(18, 4'h2, 4'h2, 4'h2, 4'h2);
    reset_n = 1'b1;
    #1;
    check(19, 4'h2, 4'h2, 4'h2, 4'h2);

    data = 4'h8;
    aset = 1'bz;
    #1;
    check(20, 4'h8, 4'h8, 4'h8, 4'h8);
    aset = 1'b0;
    #1;
    check(21, 4'h8, 4'h8, 4'h8, 4'h8);

    // Preserve all four states through an expression-driven synthesized D
    // nexus and the per-bit Vlog95 translation path.
    data = 4'bz01x;
    tick();
    check(210, 4'bz01x, 4'bz01x, 4'bz01x, 4'bz01x);

    // A dominant release and subordinate assertion in one time slot must
    // evaluate the final input state, independent of delivery order.
    reset_n = 1'b0;
    #1;
    check(22, 4'h0, 4'h0, 4'h0, 4'h0);
    aset = 1'b1;
    reset_n = 1'b1;
    #1;
    check(23, 4'ha, 4'h5, 4'hc, 4'h6);

    aset = 1'b0;
    #1;
    reset_n = 1'b0;
    #1;
    aset = 1'b1;
    reset_n = 1'b1;
    #1;
    check(24, 4'ha, 4'h5, 4'hc, 4'h6);

    reset_n = 1'b0;
    aset = 1'b0;
    #1;
    check(25, 4'h0, 4'h0, 4'h0, 4'h0);

    reset_n = 1'b1;
    aset = 1'b1;
    #1;
    check(26, 4'ha, 4'h5, 4'hc, 4'h6);
    aset = 1'b0;
    reset_n = 1'b0;
    #1;
    check(27, 4'h0, 4'h0, 4'h0, 4'h0);

    // A clock edge in the same slot as the dominant release executes the
    // remaining active control. Exercise both clock polarities and both
    // source priorities with the adverse delivery order first.
    aset = 1'b1;
    #1;
    check(28, 4'h0, 4'h5, 4'h0, 4'h6);
    clk = 1'b1;
    reset_n = 1'b1;
    #1;
    check(29, 4'ha, 4'h5, 4'h0, 4'h6);
    clk = 1'b0;
    #1;
    check(30, 4'ha, 4'h5, 4'hc, 4'h6);

    reset_n = 1'b0;
    #1;
    check(31, 4'h0, 4'h5, 4'h0, 4'h6);
    clk = 1'b1;
    aset = 1'b0;
    #1;
    check(32, 4'h0, 4'h0, 4'h0, 4'h6);
    clk = 1'b0;
    #1;
    check(33, 4'h0, 4'h0, 4'h0, 4'h0);

    aset = 1'b1;
    #1;
    check(34, 4'h0, 4'h5, 4'h0, 4'h6);
    aset = 1'b0;
    clk = 1'b1;
    #1;
    check(35, 4'h0, 4'h0, 4'h0, 4'h6);
    clk = 1'b0;
    #1;
    check(36, 4'h0, 4'h0, 4'h0, 4'h0);

`ifndef IVL_VLOG95_SIMPLE
    #1 nba_clk = 1'b1;
    #1 nba_clk = 1'b0;
    #1;
    check_nba(37, 4'h3, 4'h3, 4'h3, 4'h3);

    // A posedge-aset NBA wakes the source process while reset is still
    // active. A helper then releases reset in a causally later NBA
    // iteration. That release is not itself a source event, so clear-priority
    // state must remain clear rather than sampling the later release.
    nba_reset_n = 1'b0;
    #1;
    check_nba(38, 4'h0, 4'h0, 4'h0, 4'h0);
    fork
      begin
        @(posedge nba_aset);
        nba_reset_n <= 1'b1;
      end
    join_none
    #0;
    nba_aset <= 1'b1;
    #1;
    check_nba(39, 4'h0, 4'h5, 4'h0, 4'h6);

    // Conversely, the reset assertion wakes the source process while set is
    // still active. Releasing set in a later NBA iteration must not make the
    // set-priority state observe the subordinate clear.
    nba_aset = 1'b0;
    nba_reset_n = 1'b1;
    #1;
    nba_aset = 1'b1;
    #1;
    check_nba(40, 4'ha, 4'h5, 4'hc, 4'h6);
    fork
      begin
        @(negedge nba_reset_n);
        nba_aset <= 1'b0;
      end
    join_none
    #0;
    nba_reset_n <= 1'b0;
    #1;
    check_nba(41, 4'h0, 4'h5, 4'h0, 4'h6);

    // Derived control delivery must settle within this Active iteration.
    // An evaluator that runs before the scheduled NOT functor would pulse the
    // state high and then clear it, even though the source process observes
    // both blocking assignments before it runs and never produces that edge.
    settle_reset_n = 1'b0;
    #1 settle_reset_n = 1'b1;
    #1;
    fork
      forever begin
        @(posedge settle_state);
        settle_rises = settle_rises + 1;
      end
    join_none
    #0;
    settle_aset = 1'b1;
    settle_reset_n = 1'b0;
    #1;
    if (settle_state !== 1'b0 || settle_rises != 0) begin
      $display("FAILED -- Active settling glitch state=%b rises=%0d",
               settle_state, settle_rises);
      $finish;
    end

    // The settling point must also precede Inactive-region #0 work. The set
    // event therefore produces one real pulse before the later reset event;
    // coalescing across the #0 boundary would incorrectly erase it.
    settle_aset = 1'b0;
    settle_reset_n = 1'b1;
    #1;
    settle_rises = 0;
    settle_aset = 1'b1;
    #0 settle_reset_n = 1'b0;
    #1;
    if (settle_state !== 1'b0 || settle_rises != 1) begin
      $display("FAILED -- Active/#0 boundary state=%b rises=%0d",
               settle_state, settle_rises);
      $finish;
    end

    // A literal clock level establishes the initial input value; it is not a
    // runtime edge. Both clock polarities must therefore leave state unknown.
    if (const_posedge_state !== 4'hx || const_negedge_state !== 4'hx) begin
      $display("FAILED -- constant clock triggered state=%h/%h",
               const_posedge_state, const_negedge_state);
      $finish;
    end
`endif

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
