module r21d_write;
int aa[int];
initial begin aa[5]=17; $writememh("r21d_output.hex", aa); $display("RESULT write"); end
endmodule
