nettype logic first_nettype;
nettype logic second_nettype;

module sv_interconnect_udnt_conflict_port(input interconnect [1:0] in);
endmodule

module sv_interconnect_udnt_conflict_fail;
  first_nettype first_link;
  second_nettype second_link;

  assign first_link = 1'b0;
  assign second_link = 1'b1;

  sv_interconnect_udnt_conflict_port dut({first_link, second_link});
endmodule
