`timescale 10 ns / 1 ns
module p20a;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
parameter real pp=1.55; localparam int LP=$rtoi(7.9); localparam real PR=$bitstoreal(64'h4000000000000000);
time t1,t2; realtime r1,r2; logic [31:0] s2,sb; logic [63:0] rb; integer iv;
initial begin
 #pp; t1=$time; r1=$realtime; s2=$stime;
 #pp; t2=$time; r2=$realtime;
 ck("time_round",t1==2&&t2==3); ck("realtime",r1>1.599&&r1<1.601&&r2>3.199&&r2<3.201); ck("stime",s2==2);
 ck("bits_time",$bits($time)==64&&$bits($stime)==32);
 ck("rtoi",$rtoi(123.45)==123&&$rtoi(-2.7)==-2); iv=2.5; ck("assign_round",iv==3);
 ck("itor",$itor(123)==123.0);
 rb=$realtobits(1.5); ck("rbits",rb==64'h3FF8000000000000); ck("b2r",$bitstoreal(64'h3FF8000000000000)==1.5);
 sb=$shortrealtobits(1.5); ck("srbits",sb==32'h3FC00000); ck("b2sr",$bitstoshortreal(32'h3FC00000)==1.5);
 ck("rt",$bitstoreal($realtobits(3.14159))==3.14159); ck("const_expr",LP==7&&PR==2.0);
 $timeformat(-9,5," ns",10); $display("TF [%t]",$realtime); $display("TF2 [%t]",$time);
 $timeformat(-12,2," ps",12); $display("TF3 [%t]",$realtime);
 $printtimescale; $printtimescale(p20a);
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
