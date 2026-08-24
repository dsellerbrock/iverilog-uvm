// Two endpoint obligations resolve on one tick in each assertion. User
// actions and cbAssertionSuccess/cbAssertionFailure must retain that
// multiplicity instead of coalescing to one Boolean verdict per checker.
module m12_endpoint_fanout_cb;
  logic clk = 0;
  logic start = 0, endpoint = 0;
  logic q_pass = 0, q_fail = 0, q_eos = 0;
  integer pass_actions = 0, fail_actions = 0, eos_actions = 0;
  integer unexpected = 0;

  always #5 clk = ~clk;

  a_pass: assert property (@(posedge clk)
            start ##[1:2] endpoint |-> q_pass)
    pass_actions++;
  else unexpected++;

  a_fail: assert property (@(posedge clk)
            start ##[1:2] endpoint |-> q_fail)
    unexpected++;
  else fail_actions++;

  // The same two records remain live in this strong consequence. Its final
  // failures must retain callback multiplicity as well as action multiplicity.
  a_eos: assert property (@(posedge clk)
            start ##[1:2] endpoint |-> strong(q_pass ##[1:$] q_eos))
    unexpected++;
  else eos_actions++;

  initial #1 $setup_endpoint_fanout_cb;

  initial begin
    @(negedge clk) start = 1;
    @(negedge clk) start = 1;
    @(negedge clk) begin
      start = 0;
      endpoint = 1;
      q_pass = 1;
      q_fail = 0;
    end
    @(posedge clk);
    #1;
    if (pass_actions != 2 || fail_actions != 2 || unexpected != 0)
      $display("FAIL: endpoint fanout actions pass=%0d fail=%0d unexpected=%0d",
               pass_actions, fail_actions, unexpected);
    $check_endpoint_fanout_cb(2, 2);
    $finish;
  end

  final begin
    if (eos_actions != 2 || unexpected != 0)
      $display("FAIL: endpoint fanout EOS actions failure=%0d unexpected=%0d",
               eos_actions, unexpected);
    $check_endpoint_fanout_cb(2, 4);
  end
endmodule
