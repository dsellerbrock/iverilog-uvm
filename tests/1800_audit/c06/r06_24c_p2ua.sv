module t;
typedef byte b4_t[4]; b4_t ba;
initial begin ba=b4_t'(32'h01020304); $display("p2ua %0d %0d (expect 1 4)",ba[0],ba[3]); end
endmodule
