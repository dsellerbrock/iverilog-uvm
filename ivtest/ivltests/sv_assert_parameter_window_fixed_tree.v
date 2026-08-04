// Parameter-valued bounded consequence windows after fixed antecedents.
// Covers an overlapping [0:P] window, a nonzero [P+1:P+2] window, and
// an equal-span sequence-or antecedent. The declaration default must not
// leak into the overridden interface instance.
interface parameter_window_fixed_tree_if #(
  parameter int Skew = 9
) (
  input logic clk,
  input logic a0, h0, r0,
  input logic an, hn, rn,
  input logic ta, tb, ua, ub, rt
);
  integer zero_passes = 0;
  integer zero_failures = 0;
  integer nonzero_passes = 0;
  integer nonzero_failures = 0;
  integer tree_passes = 0;
  integer tree_failures = 0;

  sequence Left_S;
    ta ##1 tb;
  endsequence
  sequence Right_S;
    ua ##1 ub;
  endsequence

  Zero_A: assert property (@(posedge clk)
      a0 ##1 h0 |-> ##[0:Skew] r0)
    zero_passes += 1;
  else
    zero_failures += 1;

  Nonzero_A: assert property (@(posedge clk)
      an ##1 hn |-> ##[Skew+1:Skew+2] rn)
    nonzero_passes += 1;
  else
    nonzero_failures += 1;

  Tree_A: assert property (@(posedge clk)
      Left_S or Right_S |-> ##[Skew+1:Skew+2] rt)
    tree_passes += 1;
  else
    tree_failures += 1;
endinterface

module sv_assert_parameter_window_fixed_tree;
  logic clk = 0;
  logic a0 = 0, h0 = 0, r0 = 0;
  logic an = 0, hn = 0, rn = 0;
  logic ta = 0, tb = 0, ua = 0, ub = 0, rt = 0;

  always #5 clk = ~clk;

  parameter_window_fixed_tree_if #(.Skew(1)) check_if (.*);

  task automatic drive(
      input logic na0, nh0, nr0,
      input logic nan, nhn, nrn,
      input logic nta, ntb, nua, nub, nrt);
    @(negedge clk);
    a0 = na0; h0 = nh0; r0 = nr0;
    an = nan; hn = nhn; rn = nrn;
    ta = nta; tb = ntb; ua = nua; ub = nub; rt = nrt;
  endtask

  initial begin
    // All antecedents end at c2. [0:1] matches at c3; [2:3] matches
    // at c4 (tree) and c5 (flat), exercising both inclusive endpoints.
    drive(1,0,0, 1,0,0, 1,0,0,0,0); // c1
    drive(0,1,0, 0,1,0, 0,1,0,0,0); // c2
    drive(0,0,1, 0,0,0, 0,0,0,0,0); // c3
    drive(0,0,0, 0,0,0, 0,0,0,0,1); // c4
    drive(0,0,0, 0,0,1, 0,0,0,0,0); // c5
    drive(0,0,0, 0,0,0, 0,0,0,0,0); // c6

    // A second [0:1] attempt receives no result and expires at c9.
    drive(1,0,0, 0,0,0, 0,0,0,0,0); // c7
    drive(0,1,0, 0,0,0, 0,0,0,0,0); // c8
    drive(0,0,0, 0,0,0, 0,0,0,0,0); // c9
    drive(0,0,0, 0,0,0, 0,0,0,0,0); // c10 / flush
    @(negedge clk);

    if (check_if.zero_passes != 1 || check_if.zero_failures != 1)
      $display("FAILED -- [0:P] got %0d/%0d",
               check_if.zero_passes, check_if.zero_failures);
    else if (check_if.nonzero_passes != 1 || check_if.nonzero_failures != 0)
      $display("FAILED -- [P+1:P+2] got %0d/%0d",
               check_if.nonzero_passes, check_if.nonzero_failures);
    else if (check_if.tree_passes != 1 || check_if.tree_failures != 0)
      $display("FAILED -- sequence-or window got %0d/%0d",
               check_if.tree_passes, check_if.tree_failures);
    else
      $display("PASSED");
    $finish;
  end
endmodule
