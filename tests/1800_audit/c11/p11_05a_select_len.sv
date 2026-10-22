module p11e;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
logic [7:0] vect=4,v0,mem[0:7],tw[0:3][0:3]; bit [7:0] bv=8'hA5; int addr,sel=1; logic [3:0] xi=4'bx;
logic [31:0] av=32'h0123_4567; logic [0:31] bw=32'h0123_4567; logic [63:0] dw=64'h1122334455667788;
logic [15:0] a=16'hFFFF,b=1,sumA; logic [16:0] sumB;
initial begin
addr=2; ck("bit1",vect[addr]===1'b1);
addr=9; ck("bit_oob",vect[addr]===1'bx&&bv[addr]===1'b0);
ck("bit_x",vect[xi]===1'bx);
ck("part",vect[3:0]===4'b0100&&vect[5:1]===5'b00010);
ck("idx",av[0+:8]==av[7:0]&&av[15-:8]==av[15:8]&&bw[0+:8]==bw[0:7]&&bw[15-:8]==bw[8:15]);
ck("var_part",dw[8*sel+:8]==8'h77);
ck("part_oob_read",vect[9:6]===4'bxx00&&vect[15:12]===4'bxxxx);
v0=vect; vect[15:12]=4'b1111; vect[9:6]=4'b1111; ck("part_oob_write",vect[7:6]==2'b11&&vect[5:0]==v0[5:0]);
mem[3]=5; mem[5]=8'hAB; ck("mem_indirect",mem[mem[3]]==8'hAB&&mem[9]===8'bx);
tw[2][1]=8'hC3; ck("twod",tw[2][1][3:0]==4'h3&&tw[2][1][6]==1&&tw[2][1][sel]==1);
sumA=a+b; sumB=a+b; ck("sum",sumA==0&&sumB==17'h10000);
ck("ctx_cmp",(a+b)==17'h10000&&{a+b}==16'h0);
ck("bits",$bits(a+b)==16&&$bits(5)==32&&$bits(a<b)==1&&$bits(&a)==1);
$display("RESULT pass=%0d fail=%0d",p,f); end endmodule
