module t;
typedef struct {byte length; shortint address; byte payload[]; byte chksum;} Packet; typedef byte q_t[$]; Packet rk; q_t ch;
initial begin ch='{2,8'h12,8'h34,8'hAA,8'hBB,8'h11}; rk=Packet'(ch); $display("q2s %0d %0h %0d %0h (expect 2 1234 2 11)",rk.length,rk.address,rk.payload.size(),rk.chksum); end
endmodule
