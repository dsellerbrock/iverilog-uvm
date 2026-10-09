module output_slice_shape_child(output logic [7:0] data [3:0]);
  always_comb begin
    for (int i = 0; i < 4; i++)
      data[i] = i;
  end
endmodule

module test;
  logic [7:0] matrix [0:1][2:0];
  output_slice_shape_child child(.data(matrix[0]));
endmodule
