module t;
typedef byte da_t[]; da_t da; int iv;
initial begin da=da_t'(32'h01020304); $display("p2da %0d %0d (expect 4 1)",da.size(),da[0]); iv=int'(da); $display("da2p %h (expect 01020304)",iv); end
endmodule
