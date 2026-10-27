module m #(N=9)(); if (N<1||N>8) $error("Parameter N has an invalid value of %0d", N); initial $display("SIM_RAN"); endmodule
