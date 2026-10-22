module p21e;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
integer i1=0,i2=77,r; real fq=1.0; logic [8*32:1] tn; logic [64*8:1] ps;
initial begin
 ck("t_HELLO",$test$plusargs("HELLO")!=0); ck("t_HE",$test$plusargs("HE")!=0); ck("t_H",$test$plusargs("H")!=0);
 ck("t_long",$test$plusargs("HELLO_HERE")==0); ck("t_HI",$test$plusargs("HI")==0); ck("t_LO",$test$plusargs("LO")==0);
 r=$value$plusargs("TEST=%d",i1); ck("v_d",r!=0&&i1==5);
 r=$value$plusargs("TESTNAME=%s",tn); ck("v_s",r!=0&&tn[15:0]=="t1");
 r=$value$plusargs("FREQ+%0F",fq); ck("v_f",r!=0&&fq>9.233&&fq<9.235);
 r=$value$plusargs("NOSUCH=%d",i2); ck("v_none",r==0&&i2==77);
 ps="TEST%d"; r=$value$plusargs(ps,tn); $display("INFO pstring r=%0d tn=%0d",r,tn);
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
