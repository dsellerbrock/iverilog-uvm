module output_slice_driver #(parameter int BASE = 0)(
  output logic [7:0] data [3:0]
);
  always_comb begin
    for (int i = 0; i < 4; i++)
      data[i] = BASE + i;
  end
endmodule

module test;
  logic [7:0] descending [0:1][3:0];
  logic [7:0] ascending [0:1][0:3];
  logic [7:0] whole [3:0];

  output_slice_driver #(.BASE(16)) descending_row(.data(descending[0]));
  output_slice_driver #(.BASE(32)) ascending_row(.data(ascending[1]));
  output_slice_driver #(.BASE(48)) whole_array(.data(whole));

  initial begin
    #1;
    for (int i = 0; i < 4; i++) begin
      if (descending[0][i] !== (8'd16 + i))
        $fatal(1, "descending row[%0d]=%h", i, descending[0][i]);
      if (ascending[1][i] !== (8'd32 + (3 - i)))
        $fatal(1, "ascending row[%0d]=%h", i, ascending[1][i]);
      if (whole[i] !== (8'd48 + i))
        $fatal(1, "whole array[%0d]=%h", i, whole[i]);
      // IEEE 1800-2017/2023 6.5 treats unpacked array elements as
      // independent variable elements, and 6.8 gives an unassigned
      // four-state variable its default 'x value. The output-port
      // assignment in 23.3.3.2 drives only the selected row.
      if (descending[1][i] !== 8'hxx || ascending[0][i] !== 8'hxx)
        $fatal(1, "unselected variable row[%0d]=%h %h", i,
               descending[1][i], ascending[0][i]);
    end
    $display("PASSED");
  end
endmodule
