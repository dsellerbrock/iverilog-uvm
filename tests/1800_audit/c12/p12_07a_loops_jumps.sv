module p12d;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
int s,cnt,k,n,off=1,sum; string words[2]='{"hello","world"}; int prod[1:8][1:3]; int A[2][3][4]; bit [3:0][2:1] B[5:1][4]; int q[$]='{3,4,5};
logic [7:0] tmp,data=8'b1011_0110,shA,shB,res; int aa[string]; string kk; logic xc; logic [3:0] xr;
function int fr(int v); for (int i=0;i<10;i++) if (i==v) return i*10; return -1; endfunction
task automatic tr(output int o); o=1; return; o=2; endtask
initial begin
s=0; for (int i=0;i<3;i++) s+=i; ck("for",s==3);
s=0; for (int c=0,d=0,j=0;j*c<125 && j<4;j++,c++) s++; ck("for_multi",s==4);
s=0; for (int i=0,j=i+off;i<3;i++,j++) s+=j; ck("for_dep",s==6);
cnt=0; for (int i=0;;i++) begin if (i==3) break; cnt++; end ck("for_noexpr_break",cnt==3);
cnt=0; xc=1'bx; for (int i=0;xc;i++) cnt++; ck("for_x_false",cnt==0);
fork begin for (int i=0;i<3;i++) #1 sum+=1; end begin for (int i=0;i<3;i++) #1 sum+=10; end join; ck("for_local_par",sum==33);
xr=4'bx; cnt=0; repeat (xr) cnt++; ck("repeat_x",cnt==0);
cnt=0; repeat (4) cnt++; ck("repeat",cnt==4);
shA=8'h0B; shB=8'h05; res=0; repeat (4) begin if (shB[0]) res=res+shA; shA=shA<<1; shB=shB>>1; end ck("mult",res==55);
cnt=0; foreach (words[j]) cnt+=words[j].len(); ck("foreach1",cnt==10);
foreach (prod[k,m]) prod[k][m]=k*m; ck("foreach2",prod[8][3]==24&&prod[1][1]==1);
cnt=0; foreach (A[i,j,k]) cnt++; ck("foreach3",cnt==24);
cnt=0; foreach (B[q,r,,]) cnt++; ck("foreach_skip",cnt==5*4);
cnt=0; foreach (A[i,,k]) cnt+=i; ck("foreach_omit",cnt==3*4);
cnt=0; foreach (q[i]) cnt+=q[i]*i; ck("foreach_queue",cnt==14);
aa["x"]=1; aa["y"]=2; cnt=0; foreach (aa[kz]) cnt+=aa[kz]; ck("foreach_assoc",cnt==3);
cnt=0; tmp=data; while (tmp) begin if (tmp[0]) cnt++; tmp>>=1; end ck("while",cnt==5);
cnt=7; while (0) cnt=0; ck("while_never",cnt==7);
cnt=0; do cnt++; while (0); ck("do_while",cnt==1);
cnt=0; if (aa.first(kk)) do cnt+=aa[kk]; while (aa.next(kk)); ck("do_assoc",cnt==3);
cnt=0; for (int i=0;i<5;i++) begin if (i==1) continue; if (i==4) break; cnt+=i; end ck("cont_break",cnt==5);
ck("return_fn",fr(3)==30&&fr(20)==-1); tr(n); ck("return_task",n==1);
cnt=0; forever begin cnt++; if (cnt==3) break; end ck("forever_break",cnt==3);
$display("RESULT pass=%0d fail=%0d",p,f); end endmodule
