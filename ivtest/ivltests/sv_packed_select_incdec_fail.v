module sv_packed_select_incdec_fail;
  const logic [7:0] constant_value = 8'h12;
  wire [7:0] net_value;
  initial begin
    constant_value[0]++;
    net_value[1]--;
  end
endmodule
