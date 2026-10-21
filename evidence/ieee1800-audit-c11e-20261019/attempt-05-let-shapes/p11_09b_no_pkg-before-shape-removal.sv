typedef union tagged {void Invalid; int Valid;} VInt;
typedef union tagged {bit [9:0] JmpU; bit [4:0] JmpC;} Jmp_t;
typedef union tagged {Jmp_t Jmp; bit [3:0] Nop;} Instr;
module p11g2;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
bit [8*14:1] sv; bit [8*10:1] s1,s2; bit [7:0] e=""; logic a=0,b,p_=1,q=1,r=1,xm=1; logic [3:0] a4=4'hF; VInt vi1,vi2; Instr i1;
let eq(x, y = b) = x == y; let tmp = a || q; let mult(x,y) = ($bits(x)+$bits(y))'(x*y); let vy = xm; let sq(int v) = v*v;
initial begin
sv="Hello world"; ck("str1",$sformatf("%h",sv)=="00000048656c6c6f20776f726c64");
sv={sv,"!!!"}; ck("str2",$sformatf("%h",sv)=="48656c6c6f20776f726c64212121");
s1="Hello"; s2=" world!"; ck("str_pad",!({s1,s2}=="Hello world!"));
ck("empty_str",e==0&&e!="0");
$display("INFO mtm=%0d",(1:2:3)+(4:5:6));
vi1=tagged Valid(23+34); vi2=tagged Invalid;
ck("tag_valid",vi1.Valid==57&&(vi1 matches tagged Valid ? 1'b1 : 1'b0)&&(vi2 matches tagged Invalid ? 1'b1 : 1'b0));
i1=tagged Jmp(tagged JmpU 239); ck("tag_nested",i1.Jmp.JmpU==239);
b=1; ck("let_args",eq(p_,q)&&eq(r)&&tmp);
ck("let_mult",mult(a4,a4)==225);
ck("let_typed",sq(-3)==9);
begin bit xm; xm=0; a=0; b=a|vy; ck("let_ctx",b==1); end
$display("RESULT pass=%0d fail=%0d",p,f); end endmodule
