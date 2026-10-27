nettype logic nt_a;
nettype logic nt_b;

module sv_udnt_port_matching_sink(input nt_a p);
endmodule

module sv_udnt_port_matching_fail;
  nt_b actual;
  assign actual = 1'b1;
  sv_udnt_port_matching_sink dut(.p(actual));
endmodule
