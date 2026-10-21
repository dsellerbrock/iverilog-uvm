module r20_05_bitstoreal_constant;
  localparam real PR = $bitstoreal(64'h4000000000000000);
  initial $display("PR=%0.1f", PR);
endmodule
