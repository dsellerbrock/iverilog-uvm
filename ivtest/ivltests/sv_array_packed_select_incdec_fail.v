module sv_array_packed_select_incdec_fail;
  const logic [7:0] constants[0:1]='{8'ha5,8'h5a};
  wire [7:0] nets[0:1];
  initial begin
    constants[0][1]++;
    nets[1][3:0]--;
  end
endmodule
