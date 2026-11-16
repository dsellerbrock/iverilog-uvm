module top;
  wire [3:0] vec;
  wire [1:0] arr [3:2];
  wire [1:0] arr_multi [4:3][2:1];
  wire [3:0][2:1] packed_vec;
  wire scalar;
  wire [0:0] single;
  logic [3:0] var_vec;
  logic [1:0] var_arr [3:2];
  logic [1:0] var_arr_multi [4:3][2:1];
  logic [3:0][2:1] packed_var;
  initial begin
    #0;
    $probe_vpi_range;
    $finish;
  end
endmodule
