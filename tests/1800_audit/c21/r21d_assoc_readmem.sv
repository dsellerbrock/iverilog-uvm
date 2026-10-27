module r21d_read;
int aa[int];
initial begin $readmemh("r21d_input.hex", aa); $display("RESULT read size=%0d value=%0d", aa.size(), aa[5]); end
endmodule
