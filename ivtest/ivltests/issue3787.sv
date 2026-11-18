module issue3787_xor(input var logic a, input wire b, output wire y);
  assign y = a ^ b;
endmodule

module issue3787_stimulus;
  logic a [2:3];
endmodule

module issue3787_matrix(input var logic [3:0] d [1:2][7:5],
                        output wire [23:0] value);
  assign value = {d[1][7], d[1][6], d[1][5], d[2][7], d[2][6], d[2][5]};
endmodule

module issue3787_row(input var logic [3:0] d [7:6],
                      output wire [7:0] value);
  assign value = {d[7], d[6]};
endmodule

module issue3787_wide(input var logic signed [5:0] d);
endmodule

module issue3787_two_state(input var bit [1:0] d);
endmodule

module issue3787;
  issue3787_stimulus source();
  logic b [1:0];
  wire [1:0] y;
  issue3787_xor c [1:0] (source.a, b, y);

  logic [3:0] matrices [9:8][4:3][0:2];
  wire [47:0] slices;
  issue3787_matrix m [4:5] (matrices, slices);

  logic [3:0] row [0:1];
  wire [15:0] broadcast_value, pattern_value;
  issue3787_row broadcast [1:0] (row, broadcast_value);
  issue3787_row pattern [1:0] ('{row[1], row[0]}, pattern_value);

  logic [3:0] single_row [0:0][1:2];
  wire [7:0] single_value;
  issue3787_row single [5:5] (single_row, single_value);

  logic signed [2:0] narrow [7:6];
  issue3787_wide extend_signed [1:0] (narrow);
  issue3787_two_state convert [1:0] (narrow);

  initial begin
    source.a[2] = 0;
    source.a[3] = 1;
    b[1] = 1;
    b[0] = 1;

    {matrices[9][4][0], matrices[9][4][1], matrices[9][4][2],
     matrices[9][3][0], matrices[9][3][1], matrices[9][3][2]} = 24'h123456;
    {matrices[8][4][0], matrices[8][4][1], matrices[8][4][2],
     matrices[8][3][0], matrices[8][3][1], matrices[8][3][2]} = 24'hdcba98;
    {row[0], row[1]} = 8'hab;
    {single_row[0][1], single_row[0][2]} = 8'hcd;
    narrow[7] = 3'sb101;
    narrow[6] = 3'sb1xz;

    #1;
    if (y !== 2'b10) $fatal(1, "XOR mapping gave %b", y);
    $display("(%b,%b)", y[1], y[0]);
    if (slices !== 48'h123456_dcba98)
      $fatal(1, "Multidimensional split gave %h", slices);
    if (broadcast_value !== 16'habab || pattern_value !== 16'hbaba)
      $fatal(1, "Broadcast gave %h and pattern gave %h", broadcast_value, pattern_value);
    if (single_value !== 8'hcd)
      $fatal(1, "Singleton split gave %h", single_value);
    if (extend_signed[1].d !== 6'b111101 || extend_signed[0].d !== 6'b1111xz
        || convert[1].d !== 2'b01 || convert[0].d !== 2'b00)
      $fatal(1, "Scalar conversion failed");

    row[1] = 4'h5;
    #1;
    if (broadcast_value !== 16'ha5a5 || pattern_value !== 16'h5a5a)
      $fatal(1, "Updated broadcast gave %h and pattern gave %h", broadcast_value, pattern_value);

    // Forcing one input must affect only its own instance.
    force broadcast[1].d[7] = 4'h3;
    #1;
    if (broadcast_value !== 16'h35a5 || row[0] !== 4'ha)
      $fatal(1, "Input formal force leaked across the port boundary");
    release broadcast[1].d[7];
    #1;
    if (broadcast_value !== 16'ha5a5)
      $fatal(1, "Released formal did not resume following its input");
    $display("PASSED");
  end
endmodule
