module sv_interconnect_declaration_fail(interconnect logic port_link);
  interconnect logic [31:0] #(1, 2, 3) local_link = 1;
endmodule
