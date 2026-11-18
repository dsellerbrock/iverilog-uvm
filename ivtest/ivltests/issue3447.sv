`timescale 1ns/1ns
module issue3447_dut(input a, en, output reg y_edge, y_full, y_unqualified);
  always @* begin
    y_edge = a;
    y_full = a;
    y_unqualified = a;
  end

  specify
    (edge a => (y_edge : a)) = 2;
    if (en) (edge a *> (y_full : a)) = 3;
    (a => (y_unqualified : a)) = 4;
  endspecify
endmodule

module issue3447;
  reg a = 0, en = 1;
  wire y_edge, y_full, y_unqualified;
  time t_edge, t_full, t_unqualified;
  issue3447_dut dut(a, en, y_edge, y_full, y_unqualified);

  always @(y_edge) t_edge = $time;
  always @(y_full) t_full = $time;
  always @(y_unqualified) t_unqualified = $time;

  task automatic check_transition(input logic next_a, input bit qualifies);
    logic prev_a;
    time start_time, edge_delay, full_delay;
    prev_a = a;
    start_time = $time;
    edge_delay = qualifies ? 2 : 0;
    full_delay = qualifies && en ? 3 : 0;
    a = next_a;
    #5;
    if (y_edge !== next_a || t_edge !== start_time + edge_delay)
      $fatal(1, "edge path %b->%b arrived after %0d, expected %0d",
             prev_a, next_a, t_edge - start_time, edge_delay);
    if (y_full !== next_a || t_full !== start_time + full_delay)
      $fatal(1, "conditional full path %b->%b arrived after %0d, expected %0d",
             prev_a, next_a, t_full - start_time, full_delay);
    if (y_unqualified !== next_a || t_unqualified !== start_time + 4)
      $fatal(1, "unqualified path %b->%b arrived after %0d, expected 4",
             prev_a, next_a, t_unqualified - start_time);
  endtask

  initial begin
    #10;
    // Exercise every off-diagonal entry in IEEE 1800 Table 9-2.
    check_transition(1'b1, 1);
    check_transition(1'b0, 1);
    check_transition(1'bx, 1);
    check_transition(1'b1, 1);
    check_transition(1'bx, 1);
    check_transition(1'bz, 0);
    check_transition(1'b1, 1);
    check_transition(1'bz, 1);
    check_transition(1'bx, 0);
    check_transition(1'b0, 1);
    check_transition(1'bz, 1);
    check_transition(1'b0, 1);

    en = 0;
    #1;
    check_transition(1'b1, 1);
    check_transition(1'b0, 1);
    $display("PASS");
    $finish(0);
  end
endmodule
