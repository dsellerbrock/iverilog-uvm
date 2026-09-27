// OpenTitan's ASSERT_FPV_LINEAR_FSM: every state change starts an attempt
// holding the state it left, and each attempt lives until reset. A linear
// FSM keeps one live attempt per state left since reset, and attempts with
// different local values never coincide, so the attempt pool must hold them
// all (IEEE 1800-2017/2023 16.10). With 8 slots, the attempts started after
// S8 were dropped, and the return to S10 below went unreported.
module test;
  typedef enum logic [3:0] {S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11} st_e;
  logic clk = 0, rst = 1;
  st_e st;
  bit cond, back;
  int fires;
  always #5 clk = ~clk;
  always_ff @(posedge clk) if (st == S11) back <= 1;
  always_ff @(posedge clk or posedge rst)
    if (rst) begin st <= S0; cond <= 0; end
    else begin
      cond <= 1;
      if (st == S11) st <= S10;                    // not linear: back to S10
      else if (st != S10 || !back) st <= st_e'(st + 1);
    end

  property linear_p;
    st_e initial_state;
    (!$stable(st) & cond, initial_state = $past(st)) |->
        (st != initial_state) until (rst == 1'b1);
  endproperty
  linear_a: assert property (@(posedge clk) disable iff (rst) linear_p)
    else fires++;

  initial begin
    #12 rst = 0;
    #200;
    if (fires == 1) $display("PASSED");
    else $display("FAILED: linear_a fired %0d times", fires);
    $finish;
  end
endmodule
