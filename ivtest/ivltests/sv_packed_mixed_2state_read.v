// IEEE 1800-2017/2023 7.2.1: a 2-state member read from a mixed-state
// packed struct converts X/Z bits to zero.
module sv_packed_mixed_2state_read;
  typedef struct packed { bit two_state; logic four_state; } mixed_t;
  mixed_t value;
  bit scalar;

  initial begin
    value = 2'bx1;
    scalar = 1'bx;
    $display("member=%b scalar_control=%b", value.two_state, scalar);
    if (value.two_state !== 1'b0)
      $fatal(1, "2-state struct member read did not convert X to 0");
    $display("PASS packed mixed-state member read");
  end
endmodule
