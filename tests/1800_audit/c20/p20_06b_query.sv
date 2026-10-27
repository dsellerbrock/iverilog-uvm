module p20c2;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
typedef bit node; node [2:0] X; int signed Y; logic [7:0] L; real R; string S; logic [31:0] v;
typedef struct {logic valid; bit [8:1] data;} MyType; MyType mt; int unsigned U; byte B8; shortreal SR;
parameter pu=$; parameter pn=5;
initial begin
 ck("tn_vec",$typename(X)=="bit [2:0]"); ck("tn_int",$typename(Y)=="int");
 ck("tn_real",$typename(R)=="real"&&$typename(S)=="string");
 ck("tn_expr",$typename(Y+1)==$typename(int)); ck("tn_type",$typename(int)=="int");
 $display("INFO tn L=[%s] U=[%s] B=[%s] SR=[%s] mt=[%s]",$typename(L),$typename(U),$typename(B8),$typename(SR),$typename(mt));
 ck("bits_v",$bits(v)==32);
 ck("bits_types",$bits(int)==32&&$bits(byte)==8&&$bits(logic)==1&&$bits(L)==8);
 ck("bits_expr",$bits(v+1)==32&&$bits(v[3:0])==4&&$bits({v,L})==40);
 ck("bits_str",$bits("ab")==16);
 ck("unbounded",$isunbounded(pu)&&!$isunbounded(pn));
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
