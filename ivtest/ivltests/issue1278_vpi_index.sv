module top;
  wire [1:0] arr [3:2];
  wire [1:0][2:3] mda;
  logic [1:0] var_arr [3:2];
  logic [1:0][2:3] var_mda;

  initial begin
    #0;
    $display("KEEP %b %b %b %b", arr[3], mda, var_arr[3], var_mda);
    $probe_vpi_index;
    $finish;
  end
endmodule
