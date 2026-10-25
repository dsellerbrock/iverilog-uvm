module m #(N=9)(); if (N<1||N>8) $error("Parameter N invalid"); initial $display("SIM_RAN"); endmodule
