module p37(output logic [3:0] y);
  logic [7:0] v;

  initial begin
    v = 8'h5a;
    y = 4'hc;
    $check_vpi_variables;
    #1 $finish;
  end
endmodule
