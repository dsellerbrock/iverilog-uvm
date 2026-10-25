module t;
byte dq[$]; string str;
initial begin dq.push_back("A"); dq.push_back("B"); str=string'(dq); $display("q2str %s (expect AB)",str); end
endmodule
