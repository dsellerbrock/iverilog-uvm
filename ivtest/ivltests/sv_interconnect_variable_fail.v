module sv_interconnect_variable_port(input interconnect in);
endmodule

module sv_interconnect_variable_fail;
  logic variable_connection;
  sv_interconnect_variable_port dut(variable_connection);
endmodule
