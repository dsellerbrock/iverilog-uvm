// IEEE 16.7: invalid bounds or explicitly unsupported composition.
module delay_checker #(parameter D=0)(input clk,a,q);
 assert property (@(posedge clk) a |-> ##D q);
endmodule
module sv_assert_cycle_delay_unknown_fail;
 reg clk=0,a=0,q=0;delay_checker #(.D(1'bx)) u(clk,a,q);
endmodule
