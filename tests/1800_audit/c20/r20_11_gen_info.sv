module m; for (genvar i=0;i<3;i++) begin : L $info("i=%0d branch generated", i); end initial $display("SIM_RAN"); endmodule
