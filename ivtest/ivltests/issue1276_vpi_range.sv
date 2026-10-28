module top;
  wire [3:0] vec;
  wire [1:0] arr [3:2];
  wire [1:0] arr_multi [4:3][2:1];
  wire [3:0][2:1] packed_vec;
  logic [3:0] var_vec;
  logic [1:0] var_arr [3:2];
  logic [1:0] var_arr_multi [4:3][2:1];
  logic [3:0][2:1] packed_var;
  assign vec = 4'b0;
  assign arr[3] = 2'b0;
  assign arr[2] = 2'b0;
  assign arr_multi[4][2] = 2'b0;
  assign arr_multi[4][1] = 2'b0;
  assign arr_multi[3][2] = 2'b0;
  assign arr_multi[3][1] = 2'b0;
  assign packed_vec = '0;

  initial begin
    var_vec = 4'b0;
    var_arr[3] = 2'b0;
    var_arr[2] = 2'b0;
    var_arr_multi[4][2] = 2'b0;
    var_arr_multi[4][1] = 2'b0;
    var_arr_multi[3][2] = 2'b0;
    var_arr_multi[3][1] = 2'b0;
    packed_var = '0;
    #0;
    $display("VALUES %b %b %b %b %b %b %b %b", vec, arr[3], var_vec,
             var_arr[3], packed_vec, packed_var, arr_multi[4][2],
             var_arr_multi[4][2]);
    $probe_vpi_range;
    $finish;
  end
endmodule
