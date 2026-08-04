// IEEE 1800-2017 7.4.1 and 16.9.3: a sampled comparison of a fixed
// unpacked array is specialized to the actual parameter value of each
// instance.  No word from the declaration default may leak into an
// overridden instance.

module sampled_array_dut #(
  parameter int unsigned N = 2
) (
  input logic clk,
  input logic [7:0] lhs [N],
  input logic [7:0] rhs [N]
);
  int passes;
  int failures;

  property p_array_equal;
    @(posedge clk) lhs == $past(rhs);
  endproperty

  ArrayEqual_A: assert property (p_array_equal) passes++;
                else failures++;
endmodule

// Explicit nonzero ascending/descending bounds exercise the canonical
// left-to-right word mapping used by the generated snapshot/history loops.
// L and R are independently overridable; neither declaration default is a
// proxy for an instance's actual range.
module sampled_array_range_dut #(
  parameter int L = 1,
  parameter int R = 0
) (
  input logic clk,
  input logic gate,
  input logic [7:0] lhs_p1 [L:R],
  input logic [7:0] lhs_p2 [L:R],
  input logic [7:0] lhs_gate [L:R],
  input logic [7:0] rhs [L:R]
);
  int p1_passes, p1_failures;
  int sampled_passes, sampled_failures;
  int p2_passes, p2_failures;
  int gate_passes, gate_failures;
  int stable_passes, stable_failures;
  int changed_passes, changed_failures;

  Past1_A: assert property (@(posedge clk) lhs_p1 == $past(rhs))
             p1_passes++; else p1_failures++;
  Sampled_A: assert property (@(posedge clk) $sampled(lhs_p1) == $past(rhs))
             sampled_passes++; else sampled_failures++;
  Past2_A: assert property (@(posedge clk) lhs_p2 == $past(rhs, 2))
             p2_passes++; else p2_failures++;
  GatedPast_A: assert property (
             @(posedge clk) lhs_gate == $past(rhs, 1, gate))
             gate_passes++; else gate_failures++;
  Stable_A: assert property (@(posedge clk) $stable(rhs))
             stable_passes++; else stable_failures++;
  Changed_A: assert property (@(posedge clk) $changed(rhs))
             changed_passes++; else changed_failures++;
endmodule

module sv_assert_parameterized_unpacked_array_sample;
  logic clk;
  logic [7:0] lhs1 [1], rhs1 [1];
  logic [7:0] lhs2 [2], rhs2 [2];
  logic [7:0] lhs3 [3], rhs3 [3];
  logic range_clk, gate;
  logic [7:0] d_p1 [5:3], d_p2 [5:3], d_gate [5:3], d_rhs [5:3];
  logic [7:0] d_prev1 [5:3], d_prev2 [5:3], d_gate_prev [5:3];
  logic [7:0] a_p1 [4:6], a_p2 [4:6], a_gate [4:6], a_rhs [4:6];
  logic [7:0] a_prev1 [4:6], a_prev2 [4:6], a_gate_prev [4:6];
  int errors;

  sampled_array_dut #(.N(1)) u1 (.clk, .lhs(lhs1), .rhs(rhs1));
  sampled_array_dut #(.N(2)) u2 (.clk, .lhs(lhs2), .rhs(rhs2));
  sampled_array_dut #(.N(3)) u3 (.clk, .lhs(lhs3), .rhs(rhs3));

  sampled_array_range_dut #(.L(5), .R(3)) u_desc (
    .clk(range_clk), .gate,
    .lhs_p1(d_p1), .lhs_p2(d_p2), .lhs_gate(d_gate), .rhs(d_rhs)
  );
  sampled_array_range_dut #(.L(4), .R(6)) u_asc (
    .clk(range_clk), .gate,
    .lhs_p1(a_p1), .lhs_p2(a_p2), .lhs_gate(a_gate), .rhs(a_rhs)
  );

  task automatic range_tick;
    d_p1 = d_prev1;
    d_p2 = d_prev2;
    d_gate = d_gate_prev;
    a_p1 = a_prev1;
    a_p2 = a_prev2;
    a_gate = a_gate_prev;
    #4 range_clk = 1;
    #1 range_clk = 0;
    d_prev2 = d_prev1;
    d_prev1 = d_rhs;
    a_prev2 = a_prev1;
    a_prev1 = a_rhs;
    if (gate) begin
      d_gate_prev = d_rhs;
      a_gate_prev = a_rhs;
    end
  endtask

  task automatic check_range_instance(
    input string name,
    input int p1p, input int p1f,
    input int smpp, input int smpf,
    input int p2p, input int p2f,
    input int gatep, input int gatef,
    input int stablep, input int stablef,
    input int changedp, input int changedf
  );
    if (p1p != 5 || p1f != 0 || smpp != 5 || smpf != 0
        || p2p != 5 || p2f != 0 || gatep != 5 || gatef != 0
        || stablep != 2 || stablef != 3
        || changedp != 3 || changedf != 2) begin
      $display("FAIL %s p1=%0d/%0d sampled=%0d/%0d p2=%0d/%0d gate=%0d/%0d stable=%0d/%0d changed=%0d/%0d",
               name, p1p, p1f, smpp, smpf, p2p, p2f,
               gatep, gatef, stablep, stablef, changedp, changedf);
      errors++;
    end
  endtask

  initial begin
    clk = 0;
    range_clk = 0;
    gate = 0;
    lhs1 = '{default: 0}; rhs1 = '{default: 0};
    lhs2 = '{default: 0}; rhs2 = '{default: 0};
    lhs3 = '{default: 0}; rhs3 = '{default: 0};
    d_p1 = '{default: 0}; d_p2 = '{default: 0};
    d_gate = '{default: 0}; d_rhs = '{default: 0};
    d_prev1 = '{default: 0}; d_prev2 = '{default: 0};
    d_gate_prev = '{default: 0};
    a_p1 = '{default: 0}; a_p2 = '{default: 0};
    a_gate = '{default: 0}; a_rhs = '{default: 0};
    a_prev1 = '{default: 0}; a_prev2 = '{default: 0};
    a_gate_prev = '{default: 0};
    #5 clk = 1;
    #1 clk = 0;
    lhs3[2] = 8'h1;
    #4 clk = 1;
    #1;

    if (u1.passes != 2 || u1.failures != 0) begin
      $display("FAIL N=1 passes=%0d failures=%0d", u1.passes, u1.failures);
      errors++;
    end
    if (u2.passes != 2 || u2.failures != 0) begin
      $display("FAIL N=2 passes=%0d failures=%0d", u2.passes, u2.failures);
      errors++;
    end
    if (u3.passes != 1 || u3.failures != 1) begin
      $display("FAIL N=3 passes=%0d failures=%0d", u3.passes, u3.failures);
      errors++;
    end

    // Tick 1: all-zero history/current value ($stable true).
    range_tick();
    // Tick 2: change the leftmost declared word and enable gated history.
    d_rhs[5] = 8'h11;
    a_rhs[4] = 8'h11;
    gate = 1;
    range_tick();
    // Tick 3: change the middle word; gated history must hold tick 2.
    d_rhs[4] = 8'h22;
    a_rhs[5] = 8'h22;
    gate = 0;
    range_tick();
    // Tick 4: change the rightmost word and advance gated history again.
    d_rhs[3] = 8'h33;
    a_rhs[6] = 8'h33;
    gate = 1;
    range_tick();
    // Tick 5: no change, validating the opposite stable/changed verdict.
    gate = 0;
    range_tick();

    check_range_instance(
      "descending [5:3]",
      u_desc.p1_passes, u_desc.p1_failures,
      u_desc.sampled_passes, u_desc.sampled_failures,
      u_desc.p2_passes, u_desc.p2_failures,
      u_desc.gate_passes, u_desc.gate_failures,
      u_desc.stable_passes, u_desc.stable_failures,
      u_desc.changed_passes, u_desc.changed_failures
    );
    check_range_instance(
      "ascending [4:6]",
      u_asc.p1_passes, u_asc.p1_failures,
      u_asc.sampled_passes, u_asc.sampled_failures,
      u_asc.p2_passes, u_asc.p2_failures,
      u_asc.gate_passes, u_asc.gate_failures,
      u_asc.stable_passes, u_asc.stable_failures,
      u_asc.changed_passes, u_asc.changed_failures
    );

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
