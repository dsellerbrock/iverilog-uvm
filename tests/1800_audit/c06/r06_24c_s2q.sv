module t;
typedef struct {byte length; shortint address; byte payload[]; byte chksum;} Packet; typedef byte q_t[$]; Packet pk; q_t ch;
initial begin pk.length=2; pk.address=16'h1234; pk.payload='{8'hAA,8'hBB}; pk.chksum=8'h11; ch=q_t'(pk); $display("s2q %0d %0h %0h %0h %0h (expect 6 2 12 34 aa)",ch.size(),ch[0],ch[1],ch[2],ch[3]); end
endmodule
