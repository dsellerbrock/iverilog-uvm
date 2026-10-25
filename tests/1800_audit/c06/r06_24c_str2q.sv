module t;
typedef byte q_t[$]; q_t dq; string str="AB";
initial begin dq=q_t'(str); $display("str2q %0d %0d %0d (expect 2 65 66)",dq.size(),dq[0],dq[1]); end
endmodule
