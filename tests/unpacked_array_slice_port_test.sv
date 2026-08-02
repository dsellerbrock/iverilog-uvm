module unpacked_array_slice_port_child #(
  parameter int N = 2
) (
  input logic [7:0] values_i [N],
  output logic [15:0] sum_o
);
  assign sum_o = values_i[0] + values_i[1];
endmodule

module unpacked_array_slice_port_test;
  wire [7:0] matrix [2][2];
  wire [15:0] sum;
  assign matrix = '{'{8'h01, 8'h02}, '{8'h10, 8'h20}};
  unpacked_array_slice_port_child child (
    .values_i(matrix[1]),
    .sum_o(sum)
  );
  initial begin
    #1;
    if (sum !== 16'h0030)
      $fatal(1, "unpacked-array slice port failed");
    $display("PASS: unpacked-array slice port");
  end
endmodule
