// Conformance reducer for IEEE 1800-2017 16.12.7 implication semantics.
// One antecedent attempt matches at two endpoints. Each endpoint must launch
// an independent consequent obligation, even when the consequences resolve
// in opposite ways.
module endpoint_fanout_case #(
  parameter bit NONOVERLAP = 0,
  parameter bit TREE = 0,
  parameter bit COMB_ANTE = 0,
  parameter bit EARLY_PASS = 0
) (
  output integer passes,
  output integer failures
);
  logic clk = 0;
  logic start = 0, endpoint = 0;
  logic q = 0, r = 0, u = 0, v = 0;

  always #5 clk = ~clk;

  generate
    if (NONOVERLAP) begin : g_nonoverlap
      if (COMB_ANTE) begin : g_comb_ante
        ap: assert property (@(posedge clk)
              start ##1 endpoint or start ##2 endpoint |=> q ##1 r)
          passes++;
        else failures++;
      end else if (TREE) begin : g_tree
        ap: assert property (@(posedge clk)
              start ##[1:2] endpoint |=>
                (q ##1 r) or (u ##1 v))
          passes++;
        else failures++;
      end else begin : g_chain
        ap: assert property (@(posedge clk)
              start ##[1:2] endpoint |=> q ##1 r)
          passes++;
        else failures++;
      end
    end else begin : g_overlap
      if (COMB_ANTE) begin : g_comb_ante
        ap: assert property (@(posedge clk)
              start ##1 endpoint or start ##2 endpoint |-> q ##1 r)
          passes++;
        else failures++;
      end else if (TREE) begin : g_tree
        ap: assert property (@(posedge clk)
              start ##[1:2] endpoint |->
                (q ##1 r) or (u ##1 v))
          passes++;
        else failures++;
      end else begin : g_chain
        ap: assert property (@(posedge clk)
              start ##[1:2] endpoint |-> q ##1 r)
          passes++;
        else failures++;
      end
    end
  endgenerate

  initial begin
    passes = 0;
    failures = 0;

    // Anchor one antecedent attempt at t=15.
    @(negedge clk) start = 1;
    @(negedge clk) begin
      start = 0;
      endpoint = 1;
      if (!NONOVERLAP) q = 1;
    end

    // The second endpoint is t=35. For |->, it starts its consequence on
    // that tick while the first consequence resolves. For |=>, the first
    // consequence starts on that tick.
    @(negedge clk) begin
      endpoint = 1;
      if (NONOVERLAP) begin
        q = 1;
      end else begin
        r = EARLY_PASS;
        if (TREE) begin
          q = 0;
          u = 1;
        end else begin
          q = 1;
        end
      end
    end

    // For |-> this resolves the late consequence. For |=> it resolves the
    // early consequence while the late consequence starts.
    @(negedge clk) begin
      endpoint = 0;
      if (NONOVERLAP) begin
        r = EARLY_PASS;
        if (TREE) begin
          q = 0;
          u = 1;
        end else begin
          q = 1;
        end
      end else if (TREE) begin
        u = 0;
        v = !EARLY_PASS;
      end else begin
        q = 0;
        r = !EARLY_PASS;
      end
    end

    // Only |=> has one final outstanding consequence here.
    @(negedge clk) begin
      q = 0;
      r = 0;
      u = 0;
      if (NONOVERLAP && TREE)
        v = !EARLY_PASS;
      else if (NONOVERLAP)
        r = !EARLY_PASS;
    end
    @(negedge clk) begin r = 0; v = 0; end
  end
endmodule

// NO_LOCAL_FANOUT is used only to run the verdict discriminator against an
// older compiler that loudly rejects property locals before simulation.
`ifndef NO_LOCAL_FANOUT
module endpoint_fanout_local_case #(
  parameter bit NONOVERLAP = 0
) (
  output integer passes,
  output integer failures
);
  logic clk = 0;
  logic start = 0, endpoint = 0, q = 0;
  logic [7:0] tag = 0, observed = 0;
  always #5 clk = ~clk;

  generate
    if (NONOVERLAP) begin : g_nonoverlap
      property p;
        logic [7:0] saved;
        (start, saved = tag) ##[1:2] endpoint
          |=> q ##1 (observed == saved);
      endproperty
      ap: assert property (@(posedge clk) p) passes++; else failures++;
    end else begin : g_overlap
      property p;
        logic [7:0] saved;
        (start, saved = tag) ##[1:2] endpoint
          |-> q ##1 (observed == saved);
      endproperty
      ap: assert property (@(posedge clk) p) passes++; else failures++;
    end
  endgenerate

  initial begin
    passes = 0;
    failures = 0;
    @(negedge clk) begin start = 1; tag = 8'ha5; end
    @(negedge clk) begin
      start = 0; tag = 0; endpoint = 1;
      if (!NONOVERLAP) q = 1;
    end
    @(negedge clk) begin
      endpoint = 1; q = 1; observed = 8'ha5;
    end
    // The original antecedent slot is free after its second endpoint. A new
    // attempt can now reuse it and overwrite its local copy while the late
    // consequence must retain the endpoint snapshot.
    @(negedge clk) begin
      endpoint = 0;
      start = 1; tag = 8'h3c;
      q = NONOVERLAP;
      observed = 8'ha5;
    end
    @(negedge clk) begin
      start = 0; tag = 0; q = 0; observed = 8'ha5;
    end
    @(negedge clk) observed = 0;
  end
endmodule

// A local assignment on the deterministic consequence prefix is safe because
// every spawned obligation owns its own local-value record. Exercise both
// implication boundary rules while the earlier obligation resolves on the
// same tick that the later obligation captures a different value.
module endpoint_fanout_consequence_local_case #(
  parameter bit NONOVERLAP = 0
) (
  output integer passes,
  output integer failures
);
  logic clk = 0;
  logic start = 0, endpoint = 0, q = 0;
  logic [7:0] tag = 0, observed = 0;
  always #5 clk = ~clk;

  generate
    if (NONOVERLAP) begin : g_nonoverlap
      property p;
        logic [7:0] saved;
        start ##[1:2] endpoint
          |=> (q, saved = tag) ##1 (observed == saved);
      endproperty
      ap: assert property (@(posedge clk) p) passes++; else failures++;
    end else begin : g_overlap
      property p;
        logic [7:0] saved;
        start ##[1:2] endpoint
          |-> (q, saved = tag) ##1 (observed == saved);
      endproperty
      ap: assert property (@(posedge clk) p) passes++; else failures++;
    end
  endgenerate

  initial begin
    passes = 0;
    failures = 0;
    @(negedge clk) start = 1;
    @(negedge clk) begin
      start = 0;
      endpoint = 1;
      if (!NONOVERLAP) begin q = 1; tag = 8'ha5; end
    end
    @(negedge clk) begin
      endpoint = 1;
      q = 1;
      if (NONOVERLAP)
        tag = 8'ha5;
      else begin
        tag = 8'h3c;
        observed = 8'ha5;
      end
    end
    @(negedge clk) begin
      endpoint = 0;
      if (NONOVERLAP) begin
        q = 1;
        tag = 8'h3c;
        observed = 8'ha5;
      end else begin
        q = 0;
        observed = 8'h3c;
      end
    end
    @(negedge clk) begin q = 0; observed = 8'h3c; end
    @(negedge clk) observed = 0;
  end
endmodule
`endif

// Two distinct antecedent attempts accept on one sampled tick. Their
// consequences therefore resolve together; each verdict must execute its
// own action (and, through the same dispatch, its own success/failure
// callback).
module endpoint_fanout_coincident_case #(
  parameter bit NONOVERLAP = 0,
  parameter bit EXPECT_PASS = 0
) (
  output integer passes,
  output integer failures
);
  logic clk = 0;
  logic start = 0, endpoint = 0, q = 0;
  always #5 clk = ~clk;

  generate
    if (NONOVERLAP) begin : g_nonoverlap
      ap: assert property (@(posedge clk)
            start ##[1:2] endpoint |=> q)
        passes++;
      else failures++;
    end else begin : g_overlap
      ap: assert property (@(posedge clk)
            start ##[1:2] endpoint |-> q)
        passes++;
      else failures++;
    end
  endgenerate

  initial begin
    passes = 0;
    failures = 0;
    @(negedge clk) start = 1;
    @(negedge clk) start = 1;
    @(negedge clk) begin
      start = 0;
      endpoint = 1;
      if (!NONOVERLAP) q = EXPECT_PASS;
    end
    @(negedge clk) begin
      endpoint = 0;
      q = NONOVERLAP ? EXPECT_PASS : 0;
    end
    @(negedge clk) q = 0;
  end
endmodule

// A strong consequence that is still live at end of simulation fails once
// for every obligation record, not once for the checker. Two antecedent
// attempts deliberately reach one endpoint tick and leave two independent
// unbounded consequences pending.
module endpoint_fanout_strong_eos_case (
  output integer failures
);
  logic clk = 0;
  logic start = 0, endpoint = 0, q = 0, r = 0;
  always #5 clk = ~clk;

  ap: assert property (@(posedge clk)
        start ##[1:2] endpoint |-> strong(q ##[1:$] r))
    else failures++;

  initial begin
    failures = 0;
    @(negedge clk) start = 1;
    @(negedge clk) start = 1;
    @(negedge clk) begin
      start = 0;
      endpoint = 1;
      q = 1;
    end
    @(negedge clk) begin
      endpoint = 0;
      q = 0;
    end
  end

  final begin
    $display("EOS_FAILURE %0d", failures);
    if (failures != 2)
      $fatal(1, "strong EOS obligations were coalesced");
  end
endmodule

// A dependent match-item RHS must read an earlier property local from this
// antecedent attempt. The module-level `first' is a deliberate collision: a
// shared/global RHS evaluation produces 8'hef and fails both obligations.
module endpoint_dependent_antecedent_local_case (
  output integer passes,
  output integer failures
);
  logic clk = 0;
  logic start = 0, mid = 0, endpoint = 0;
  logic [7:0] tag = 0, route = 0, observed = 0;
  logic [7:0] first = 8'hee;
  always #5 clk = ~clk;

  property p;
    logic [7:0] first;
    logic [7:0] second;
    (start, first = tag) ##1 (mid, second = first + 1)
      ##[1:2] (endpoint && route == first) |-> (observed == second);
  endproperty
  ap: assert property (@(posedge clk) p) passes++; else failures++;

  initial begin
    passes = 0;
    failures = 0;
    @(negedge clk) begin start = 1; tag = 8'h10; end
    @(negedge clk) begin start = 1; tag = 8'h20; mid = 1; end
    @(negedge clk) begin
      start = 0; endpoint = 1; route = 8'h10; observed = 8'h11;
    end
    @(negedge clk) begin
      mid = 0; endpoint = 1; route = 8'h20; observed = 8'h21;
    end
    @(negedge clk) begin endpoint = 0; route = 0; observed = 0; end
  end
endmodule

// The same dependency on the consequence side is per obligation. At t=35
// one record reads its old `first' into `second' while its sibling captures a
// different `first'; neither may observe the module-level collision.
module endpoint_dependent_consequence_local_case (
  output integer passes,
  output integer failures
);
  logic clk = 0;
  logic start = 0, endpoint = 0, q = 0, mid = 0;
  logic [7:0] tag = 0, observed = 0;
  logic [7:0] first = 8'hee;
  always #5 clk = ~clk;

  property p;
    logic [7:0] first;
    logic [7:0] second;
    start ##[1:2] endpoint |->
      (q, first = tag) ##1 (mid, second = first + 1)
        ##1 (observed == second);
  endproperty
  ap: assert property (@(posedge clk) p) passes++; else failures++;

  initial begin
    passes = 0;
    failures = 0;
    @(negedge clk) start = 1;
    @(negedge clk) begin
      start = 0; endpoint = 1; q = 1; tag = 8'h10;
    end
    @(negedge clk) begin
      endpoint = 1; q = 1; tag = 8'h20; mid = 1;
    end
    @(negedge clk) begin
      endpoint = 0; q = 0; mid = 1; observed = 8'h11;
    end
    @(negedge clk) begin mid = 0; observed = 8'h21; end
    @(negedge clk) observed = 0;
  end
endmodule

// Lower bounds of one are not fused. Keep bounded and unbounded controls on
// both sides of the implication so the zero-inclusive audit cannot reject a
// later-edge local read merely because its upper bound is variable.
module endpoint_nonzero_local_read_case #(
  parameter bit CONSEQUENCE = 0,
  parameter bit UNBOUNDED = 0
) (
  output integer passes,
  output integer failures
);
  logic clk = 0;
  logic start = 0, endpoint = 0, q = 0;
  logic [7:0] tag = 0, observed = 0;
  always #5 clk = ~clk;

  generate
    if (!CONSEQUENCE) begin : g_ante
      if (!UNBOUNDED) begin : g_bounded
        property p;
          logic [7:0] saved;
          (start, saved = tag) ##[1:2] (endpoint && observed == saved)
            |-> q;
        endproperty
        ap: assert property (@(posedge clk) p) passes++; else failures++;
      end else begin : g_unbounded
        property p;
          logic [7:0] saved;
          (start, saved = tag) ##[1:$] (endpoint && observed == saved)
            |-> q;
        endproperty
        ap: assert property (@(posedge clk) p) passes++; else failures++;
      end
    end else begin : g_cons
      if (!UNBOUNDED) begin : g_bounded
        property p;
          logic [7:0] saved;
          start ##[1:2] endpoint
            |-> (q, saved = tag) ##[1:2] (observed == saved);
        endproperty
        ap: assert property (@(posedge clk) p) passes++; else failures++;
      end else begin : g_unbounded
        property p;
          logic [7:0] saved;
          start ##[1:2] endpoint
            |-> (q, saved = tag) ##[1:$] (observed == saved);
        endproperty
        ap: assert property (@(posedge clk) p) passes++; else failures++;
      end
    end
  endgenerate

  initial begin
    passes = 0;
    failures = 0;
    @(negedge clk) begin start = 1; tag = 8'ha5; end
    @(negedge clk) begin
      start = 0; endpoint = 1; q = 1; observed = 8'ha5;
    end
    @(negedge clk) begin endpoint = 0; q = 0; observed = 8'ha5; end
    @(negedge clk) observed = 0;
  end
endmodule

module endpoint_obligation_fanout_nfa_only;
  integer p0, f0, p1, f1, p2, f2, p3, f3;
  integer p4, f4, p5, f5, p6, f6, p7, f7;
  integer p8, f8, p9, f9, p10, f10, p11, f11;
`ifndef NO_LOCAL_FANOUT
  integer pl0, fl0, pl1, fl1;
  integer pcl0, fcl0, pcl1, fcl1;
`endif
  integer pc0, fc0, pc1, fc1, pc2, fc2, pc3, fc3;
  integer eos_failures;
  integer pda, fda, pdc, fdc;
  integer pn0, fn0, pn1, fn1, pn2, fn2, pn3, fn3;

  endpoint_fanout_case #(.NONOVERLAP(0), .TREE(0), .EARLY_PASS(1)) c0(p0,f0);
  endpoint_fanout_case #(.NONOVERLAP(0), .TREE(0), .EARLY_PASS(0)) c1(p1,f1);
  endpoint_fanout_case #(.NONOVERLAP(0), .TREE(1), .EARLY_PASS(1)) c2(p2,f2);
  endpoint_fanout_case #(.NONOVERLAP(0), .TREE(1), .EARLY_PASS(0)) c3(p3,f3);
  endpoint_fanout_case #(.NONOVERLAP(1), .TREE(0), .EARLY_PASS(1)) c4(p4,f4);
  endpoint_fanout_case #(.NONOVERLAP(1), .TREE(0), .EARLY_PASS(0)) c5(p5,f5);
  endpoint_fanout_case #(.NONOVERLAP(1), .TREE(1), .EARLY_PASS(1)) c6(p6,f6);
  endpoint_fanout_case #(.NONOVERLAP(1), .TREE(1), .EARLY_PASS(0)) c7(p7,f7);
  endpoint_fanout_case #(.NONOVERLAP(0), .COMB_ANTE(1), .EARLY_PASS(1)) c8(p8,f8);
  endpoint_fanout_case #(.NONOVERLAP(0), .COMB_ANTE(1), .EARLY_PASS(0)) c9(p9,f9);
  endpoint_fanout_case #(.NONOVERLAP(1), .COMB_ANTE(1), .EARLY_PASS(1)) c10(p10,f10);
  endpoint_fanout_case #(.NONOVERLAP(1), .COMB_ANTE(1), .EARLY_PASS(0)) c11(p11,f11);
`ifndef NO_LOCAL_FANOUT
  endpoint_fanout_local_case #(.NONOVERLAP(0)) cl0(pl0,fl0);
  endpoint_fanout_local_case #(.NONOVERLAP(1)) cl1(pl1,fl1);
  endpoint_fanout_consequence_local_case #(.NONOVERLAP(0))
    ccl0(pcl0,fcl0);
  endpoint_fanout_consequence_local_case #(.NONOVERLAP(1))
    ccl1(pcl1,fcl1);
`endif
  endpoint_fanout_coincident_case #(.NONOVERLAP(0), .EXPECT_PASS(1))
    cc0(pc0,fc0);
  endpoint_fanout_coincident_case #(.NONOVERLAP(0), .EXPECT_PASS(0))
    cc1(pc1,fc1);
  endpoint_fanout_coincident_case #(.NONOVERLAP(1), .EXPECT_PASS(1))
    cc2(pc2,fc2);
  endpoint_fanout_coincident_case #(.NONOVERLAP(1), .EXPECT_PASS(0))
    cc3(pc3,fc3);
  endpoint_fanout_strong_eos_case eos(eos_failures);
  endpoint_dependent_antecedent_local_case da(pda,fda);
  endpoint_dependent_consequence_local_case dc(pdc,fdc);
  endpoint_nonzero_local_read_case #(.CONSEQUENCE(0), .UNBOUNDED(0))
    nz0(pn0,fn0);
  endpoint_nonzero_local_read_case #(.CONSEQUENCE(0), .UNBOUNDED(1))
    nz1(pn1,fn1);
  endpoint_nonzero_local_read_case #(.CONSEQUENCE(1), .UNBOUNDED(0))
    nz2(pn2,fn2);
  endpoint_nonzero_local_read_case #(.CONSEQUENCE(1), .UNBOUNDED(1))
    nz3(pn3,fn3);

  initial begin
    #90;
    $display("fanout counts %0d/%0d %0d/%0d %0d/%0d %0d/%0d %0d/%0d %0d/%0d %0d/%0d %0d/%0d",
      p0,f0,p1,f1,p2,f2,p3,f3,p4,f4,p5,f5,p6,f6,p7,f7);
    if ({p0,f0,p1,f1,p2,f2,p3,f3,p4,f4,p5,f5,p6,f6,p7,f7}
        !== {32'd1,32'd1,32'd1,32'd1,32'd1,32'd1,32'd1,32'd1,
             32'd1,32'd1,32'd1,32'd1,32'd1,32'd1,32'd1,32'd1})
      $fatal(1, "endpoint obligations were merged");
    $display("combinator counts %0d/%0d %0d/%0d %0d/%0d %0d/%0d",
      p8,f8,p9,f9,p10,f10,p11,f11);
    if ({p8,f8,p9,f9,p10,f10,p11,f11}
        !== {32'd1,32'd1,32'd1,32'd1,32'd1,32'd1,32'd1,32'd1})
      $fatal(1, "combinator endpoints did not fan out");
`ifndef NO_LOCAL_FANOUT
    $display("local fanout counts %0d/%0d %0d/%0d", pl0,fl0,pl1,fl1);
    if ({pl0,fl0,pl1,fl1} !== {32'd2,32'd0,32'd2,32'd0})
      $fatal(1, "endpoint-local snapshots were not independent");
    $display("consequence-local counts %0d/%0d %0d/%0d",
      pcl0,fcl0,pcl1,fcl1);
    if ({pcl0,fcl0,pcl1,fcl1} !== {32'd2,32'd0,32'd2,32'd0})
      $fatal(1, "consequence-local snapshots were not independent");
`endif
    $display("coincident counts %0d/%0d %0d/%0d %0d/%0d %0d/%0d",
      pc0,fc0,pc1,fc1,pc2,fc2,pc3,fc3);
    if ({pc0,fc0,pc1,fc1,pc2,fc2,pc3,fc3}
        !== {32'd2,32'd0,32'd0,32'd2,32'd2,32'd0,32'd0,32'd2})
      $fatal(1, "same-tick endpoint verdict actions were coalesced");
    $display("dependent local counts %0d/%0d %0d/%0d",
      pda,fda,pdc,fdc);
    if ({pda,fda,pdc,fdc} !== {32'd2,32'd0,32'd2,32'd0})
      $fatal(1, "dependent local RHS escaped its attempt or obligation");
    $display("nonzero local counts %0d/%0d %0d/%0d %0d/%0d %0d/%0d",
      pn0,fn0,pn1,fn1,pn2,fn2,pn3,fn3);
    if ({pn0,fn0,pn1,fn1,pn2,fn2,pn3,fn3}
        !== {32'd1,32'd0,32'd1,32'd0,32'd1,32'd0,32'd1,32'd0})
      $fatal(1, "a nonzero local-read continuation was rejected or misrun");
    $display("PASSED");
    $finish(0);
  end
endmodule
