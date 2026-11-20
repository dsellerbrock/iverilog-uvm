module source(output wire bit_out,
              output wire [4:2] vec_out,
              output wire real real_out);
  reg bit_data = 1'b0;
  real real_data = 1.25;
  assign bit_out = bit_data;
  assign vec_out = 3'b101;
  assign real_out = real_data;

  initial begin
    #2;
    bit_data = 1'b1;
    real_data = -2.5;
  end
endmodule

module top;
  interconnect bit_link, vec_link, real_link;
  source src(bit_link, vec_link, real_link);

  initial begin
    #1 $probe_interconnect(0);
    #2 $probe_interconnect(1);
  end
endmodule
