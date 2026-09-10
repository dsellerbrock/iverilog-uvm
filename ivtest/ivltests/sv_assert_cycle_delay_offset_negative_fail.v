// IEEE 16.7: invalid bounds or explicitly unsupported composition.
module delay_checker #(parameter D=0)(input clk,a,q);
 assert property (@(posedge clk) a |-> ##D (##2 q));
endmodule
module sv_assert_cycle_delay_offset_negative_fail;
 reg clk=0,a=0,q=0;delay_checker #(.D(-1)) u(clk,a,q);
endmodule
