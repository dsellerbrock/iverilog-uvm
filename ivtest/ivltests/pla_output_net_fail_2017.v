module pla_output_net_fail_2017;
  logic [1:1] mem [1:1];
  logic a;
  wire y;
  initial $async$and$array(mem, a, y);
endmodule
