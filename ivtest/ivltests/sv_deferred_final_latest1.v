// Stage 1 deliberately refuses `final`: IEEE 1800-2017 16.4 requires a
// Postponed report in every time step, not one end-of-simulation action.
module t;
  initial assert final (0) else $display("must not be lowered at EOS");
endmodule
