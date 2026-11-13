`timescale 1ns/1ps
primitive udp_one(q, a);
  output reg q; input a;
  initial q = 1'b1;
  table
    0 : ? : -;
    1 : ? : 0;
  endtable
endprimitive

primitive udp_zero(q, a);
  output reg q; input a;
  initial q = 1'b0;
  table
    0 : ? : -;
    1 : ? : 1;
  endtable
endprimitive

primitive udp_no_initial(q, a);
  output reg q; input a;
  table
    0 : ? : 1;
    1 : ? : -;
  endtable
endprimitive

module issue3079_udp_initial_delay;
  reg a = 0, b = 1;
  integer delay_value = 5;
  wire q1, q0, q_variable, q_unknown, immediate_transition, plain, downstream;
  udp_one #(5, 5) u1(q1, a), u2(immediate_transition, b);
  udp_one #(delay_value, delay_value) u5(q_variable, a);
  udp_zero #(5, 5) u0(q0, a);
  udp_no_initial #(5, 5) u6(q_unknown, a);
  udp_one u3(plain, a);
  buf #2 u4(downstream, q1);

  initial begin
    #1;
    if (q1 !== 1 || q0 !== 0 || q_variable !== 1 || immediate_transition !== 1 ||
        plain !== 1 || q_unknown !== 1'bx || downstream !== 1'bx)
      $fatal(1, "incorrect initialization: %b %b %b %b %b",
             q1, q0, immediate_transition, plain, downstream);
    #2;
    if (downstream !== 1) $fatal(1, "downstream delay failed");
    a = 1;
    #1;
    if (q1 !== 1 || q0 !== 0 || q_variable !== 1 || immediate_transition !== 1 || plain !== 0)
      $fatal(1, "transition occurred too early");
    #2;
    if (immediate_transition !== 0 || q1 !== 1 || q0 !== 0 || q_unknown !== 1)
      $fatal(1, "time-zero transition delay failed");
    #3;
    if (q1 !== 0 || q0 !== 1 || q_variable !== 0 || downstream !== 1)
      $fatal(1, "instance delay failed");
    #2;
    if (downstream !== 0) $fatal(1, "downstream transition delay failed");
    $display("PASS");
  end
endmodule
