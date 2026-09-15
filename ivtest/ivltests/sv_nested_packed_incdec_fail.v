module sv_nested_packed_incdec_fail;
  const logic [1:0][7:0] constant_value = '0;
  wire [1:0][7:0] net_value;
  initial begin
    constant_value[0][1]++;
    net_value[0][1]--;
  end
endmodule
