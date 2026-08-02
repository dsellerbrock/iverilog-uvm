package unpacked_array_parameter_port_pkg;
  parameter int Values [3] = '{2, 7, 4};
endpackage

module unpacked_array_parameter_port_child(
  input int values_i [3],
  output int sum_o
);
  assign sum_o = values_i[0] + values_i[1] + values_i[2];
endmodule

module unpacked_array_parameter_port_test;
  import unpacked_array_parameter_port_pkg::*;
  wire [31:0] sum;
  unpacked_array_parameter_port_child child (
    .values_i(Values),
    .sum_o(sum)
  );
  initial begin
    #1;
    if (sum !== 13)
      $fatal(1, "unpacked-array parameter port failed");
    $display("PASS: unpacked-array parameter port");
  end
endmodule
