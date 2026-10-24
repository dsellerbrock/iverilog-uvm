module p21b;
 typedef enum {ON, OFF} sw_e; typedef struct {sw_e sw; string s;} pair_t;
 int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
 supply1 s_su; wire (strong1,strong0) w_st = 1'b1; pulldown(pd); tri1 t1; wire w_z;
 pair_t va[int] = '{10:'{OFF,"switch10"}, 20:'{ON,"switch20"}};
 int b=0, a=0; string s,fm="v=%0d"; byte arr[2]='{"x","y"}; integer fd, mcd, rd;
 task t; $display("MT %m"); endtask
 initial begin : B
  $display("MM %m"); t();
  ck("v",$sformatf("%v|%v|%v|%v|%v",s_su,w_st,pd,w_z,t1)=="Su1|St1|Pu0|HiZ|Pu1");
  s=$sformatf("%s",32'h00006162); $display("INFO s_int [%s]",s); ck("s_int",s=="ab");
  s=$sformatf("%s",arr); $display("INFO s_array [%s]",s); ck("s_array",s=="xy");
  ck("p_str",$sformatf("%p",va[10].s)=="\"switch10\"");
  $display("INFO p %p",va); $display("INFO 0p %0p",va);
  a=1; $strobe("S a=%0d",a); $display("D a=%0d",a); a=2;
  $swrite(s,"a=%0d",5); ck("swrite",s=="a=5"); $swriteh(s,255); ck("swriteh",s=="000000ff");
  $sformat(s,fm,7); ck("sformat_var",s=="v=7"); $sformat(s,"%0d %0d",1); $display("INFO sformat_short [%s]",s);
  fd=$fopen("p21_tmp.txt","w"); ck("fd",fd[31]==1&&fd!=0); $fwrite(fd,"abc\nxyz\n"); $fclose(fd);
  fd=$fopen("p21_tmp.txt","r"); rd=$fgets(s,fd); ck("fgets",s=="abc\n"&&rd==4); $fclose(fd);
  mcd=$fopen("p21_tmp2.txt"); ck("mcd",mcd[31]==0&&mcd==2); $fdisplay(mcd|1,"BOTH"); $fclose(mcd);
  $fdisplay(32'h8000_0001,"FD1"); $fdisplay(1,"MCD1");
  ck("fopen_fail",$fopen("no_such_dir/x.txt","r")==0);
  $monitor("M t=%0t b=%0d",$time,b); #1 b=2; #1 b=2; #1 b=3; #1 $monitoroff; b=4; #1 $monitoron; #1 b=5; #1;
  $display("RESULT pass=%0d fail=%0d",p,f); $finish; end endmodule
