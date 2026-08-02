module sva_recursive_consequent_local_var_test;
  typedef enum logic [1:0] {Reset, Run, Stop, Error} state_e;
  bit clk, rst, cond;
  state_e state;
  int failures;

  always #5 clk = ~clk;

  property linear_fsm_p;
    state_e initial_state;
    (!$stable(state) & cond, initial_state = $past(state)) |->
        (state != initial_state) until !(cond);
  endproperty

  assert property (@(posedge clk) disable iff (rst) linear_fsm_p)
    ; else failures++;

  initial begin
    rst = 1;
    @(negedge clk);
    rst = 0;
    cond = 1;
    state = Run;
    @(negedge clk);
    state = Stop;
    repeat (2) @(negedge clk);
    cond = 0;
    @(negedge clk);
    if (failures != 0) $fatal(1, "linear FSM property failed");
    $display("PASS: recursive consequent preserves local variable context");
    $finish;
  end
endmodule
