module t;
typedef byte b4_t[4]; b4_t ba; int iv;
initial begin ba='{1,2,3,4}; iv=int'(ba); $display("ua2p %h (expect 01020304)",iv); end
endmodule
