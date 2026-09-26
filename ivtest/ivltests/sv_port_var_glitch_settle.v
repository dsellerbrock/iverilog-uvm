// A port connection from a variable is a continuous assignment, a process
// that runs after the writing process suspends (IEEE 1800-2017/2023 10.3,
// 23.3.3). It must not forward the intermediate values of a
// default-then-override sequence. Otherwise these always_comb blocks, coupled
// through ports, trigger each other forever at one time step (OpenTitan
// lc_ctrl: the FSM idle_o and the CSR block's transition_cmd).
module fsm(input logic cmd_i, output logic idle_o, output logic busy_o);
  int evals = 0;
  always_comb begin
    evals++;
    idle_o = 1'b0;
    busy_o = 1'b0;
    idle_o = 1'b1;
    if (cmd_i) busy_o = 1'b1;
  end
endmodule

module test;
  logic idle, busy, cmd, req = 0;
  int evals = 0, idle_changes = 0;
  fsm u_fsm(.cmd_i(cmd), .idle_o(idle), .busy_o(busy));
  always_comb begin
    evals++;
    cmd = 1'b0;
    if (idle) cmd = req;
  end
  always @(idle) idle_changes++;
  initial begin
    #1 req = 1;
    #1;
    if (idle !== 1'b1 || cmd !== 1'b1 || busy !== 1'b1)
      $display("FAILED values idle=%b cmd=%b busy=%b", idle, cmd, busy);
    else if (idle_changes != 1 || evals > 4 || u_fsm.evals > 4)
      $display("FAILED glitches idle_changes=%0d evals=%0d/%0d",
               idle_changes, evals, u_fsm.evals);
    else
      $display("PASSED");
    $finish;
  end
endmodule
