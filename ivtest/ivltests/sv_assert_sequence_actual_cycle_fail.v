// IEEE 16.8 includes instantiation in actual arguments in cycle edges.
module sv_assert_sequence_actual_cycle_fail;
 reg clk=0,a=1;
 sequence Wrap(x); x; endsequence
 assert property (@(posedge clk) Wrap(Wrap(a)));
endmodule
