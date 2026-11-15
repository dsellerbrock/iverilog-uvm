// IEEE 1800-2023 6.7.1: a net needs a 4-state data type. Icarus accepts
// 2-state nets as an extension and, under -Wnet-data-type (part of -Wall),
// warns (IEEE_RULINGS #819, #2851). Variables are not nets.
module issue2851_net_2state_m(input bit [7:0] a, input var bit [3:0] v,
                              output bit o, input int i);
  wire bit [1:0] w = 2'b10;
  bit b;
  assign o = 1'b0;
  initial #1 $display("a=%0d v=%0d i=%0d w=%0d", a, v, i, w);
endmodule

module issue2851_net_2state;
  wire o;
  issue2851_net_2state_m u(8'd5, 4'd1, o, 3);
endmodule
