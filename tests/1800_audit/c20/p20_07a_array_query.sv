module p20d;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
logic [3:0][2:1] n [1:5][2:8]; typedef logic [16:1] Word; Word Ram[0:9];
int a[3][][5]; int d[]; int q[$]; int aa[int]; integer N; shortint SI; byte BY; string S; logic [7:0] V; bit [0:7] RV; int sc;
initial begin
 ck("dims",$dimensions(n)==4&&$unpacked_dimensions(n)==2&&$dimensions(V)==1&&$dimensions(S)==1&&$dimensions(sc)==1);
 ck("dims_type",$dimensions(Word)==1&&$unpacked_dimensions(V)==0&&$unpacked_dimensions(a)==3);
 ck("d1",$left(n,1)==1&&$right(n,1)==5&&$low(n,1)==1&&$high(n,1)==5&&$increment(n,1)==-1&&$size(n,1)==5);
 ck("d2",$left(n,2)==2&&$right(n,2)==8&&$increment(n,2)==-1&&$size(n,2)==7);
 ck("d3",$left(n,3)==3&&$right(n,3)==0&&$low(n,3)==0&&$high(n,3)==3&&$increment(n,3)==1&&$size(n,3)==4);
 ck("d4",$left(n,4)==2&&$right(n,4)==1&&$low(n,4)==1&&$high(n,4)==2&&$increment(n,4)==1&&$size(n,4)==2);
 ck("default_dim",$left(V)==7&&$right(V)==0&&$increment(V)==1&&$size(V)==8&&$left(RV)==0&&$right(RV)==7&&$increment(RV)==-1);
 ck("type_arg",$size(Word)==16&&$size(Ram,2)==16&&$size(Ram)==10&&$left(Word)==16&&$right(Word)==1);
 ck("int_types",$left(N)==31&&$right(N)==0&&$left(SI)==15&&$left(BY)==7&&$size(BY)==8&&$left(int)==31);
 ck("oor_x",$isunknown($left(n,9))&&$isunknown($size(sc,2))&&$isunknown($left(sc,0)));
 d=new[4]; ck("dyn",$left(d)==0&&$right(d)==3&&$increment(d)==-1&&$size(d)==4&&$low(d)==0&&$high(d)==3);
 d=new[0]; ck("dyn_empty",$size(d)==0&&$right(d)==-1);
 q.push_back(7); q.push_back(8); ck("queue",$left(q)==0&&$right(q)==1&&$size(q)==2&&$increment(q)==-1);
 aa[5]=1; aa[2]=1; aa[9]=1; ck("assoc",$left(aa)==0&&$right(aa)>=9&&$low(aa)==2&&$high(aa)==9&&$increment(aa)==-1&&$size(aa)==3);
 aa.delete(); ck("assoc_empty",$isunknown($low(aa))&&$isunknown($high(aa))&&$size(aa)==0);
 a[2]=new[4]; ck("multi",$unpacked_dimensions(a)==3&&$size(a,1)==3&&$size(a,3)==5&&$size(a[2],1)==4&&$size(a[1],1)==0);
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
