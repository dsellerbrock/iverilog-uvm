module p11c;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
class K; endclass
logic [15:0] A=16'b0000_1111_xxxx_zzzz, B=16'b01xz_01xz_01xz_01xz;
logic signed [3:0] s=4'b1000; logic [3:0] u=4'b1000, st=1, r4; int cnt=0; K h=new,h2;
function int sc(); cnt++; return 1; endfunction
initial begin
ck("and",(A&B)===16'b0000_01xx_0xxx_0xxx);
ck("or",(A|B)===16'b01xx_1111_x1xx_x1xx);
ck("xor",(A^B)===16'b01xx_10xx_xxxx_xxxx);
ck("xnor",(A~^B)===16'b10xx_01xx_xxxx_xxxx);
ck("not",(~A)===16'b1111_0000_xxxx_xxxx);
ck("red0110",&4'b0110===0&&~&4'b0110===1&&|4'b0110===1&&~|4'b0110===0&&^4'b0110===0&&~^4'b0110===1);
ck("red1000",&4'b1000===0&&|4'b1000===1&&^4'b1000===1&&~^4'b1000===0);
ck("red0000",~&4'b0000===1&&~|4'b0000===1&&~^4'b0000===1);
ck("red_x",&4'b01x1===0&&|4'b01x0===1&&^4'b01x0===1'bx);
ck("shl",(st<<2)==4'b0100);
r4=s>>>2; ck("ashr_signed",r4==4'b1110);
r4=u>>>2; ck("ashr_unsigned",r4==4'b0010);
r4=s>>2; ck("lshr",r4==4'b0010);
ck("shift_x",(4'b1000>>1'bx)===4'bxxxx);
ck("cond_x",(1'bx ? 4'b0101 : 4'b0110)===4'b01xx&&(1'bx ? 4'b0101 : 4'b0101)===4'b0101&&(1'bz ? 4'b1100 : 4'b1010)===4'b1xx0);
ck("cond_real",(1 ? 1 : 2.5)==1.0&&(1 ? 3 : 2.5)/2==1.5);
h2=1 ? h : null; ck("cond_handle",h2==h&&(0 ? h : null)==null);
cnt=0; r4=(1'bx ? sc() : sc()); ck("cond_x_both",cnt==2);
cnt=0; r4=(1 ? 1 : sc()); r4=(0 ? sc() : 1); ck("cond_lazy",cnt==0);
$display("RESULT pass=%0d fail=%0d",p,f); end endmodule
