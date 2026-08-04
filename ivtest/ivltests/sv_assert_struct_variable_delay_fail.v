// A selected member of a run-time struct variable is not a constant
// expression and therefore remains illegal as an SVA cycle-delay bound.
module sv_assert_struct_variable_delay_fail;
  typedef struct packed {
    int min;
    int max;
  } bounds_t;

  logic clk, req, ack;
  bounds_t cycles;

  bad: assert property (@(posedge clk)
      req |-> ##[cycles.min:cycles.max] ack);
endmodule
