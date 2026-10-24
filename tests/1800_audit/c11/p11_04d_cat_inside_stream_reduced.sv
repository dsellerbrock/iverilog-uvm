module p11d;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
parameter P=32; int cnt=0,x,y,z,n=3,ua,ub,uc,j={"A","B","C","D"},w1=32'h11223344,ia[$]='{3,4,5};
function int fn(int v); cnt++; return v; endfunction
byte a=3,b=2,arr[4]='{1,2,3,4},qb[$],qq[$]; bit [1:0] c; logic l1,l2,l3; logic [31:0] aa=32'hDEADBEEF,r32;
string h="hello",s,s2; bit [31:0] r; bit [7:0] r8; logic [5:0] r6; logic [3:0] r4; logic [10:0] up[3:0],p1,p2,p3,p4;
initial begin
c={a+b}[1:0]; ck("sel",c==1);
{l1,l2,l3}=3'b101; ck("lhs",l1==1&&l2==0&&l3==1);
r32={{32-P{1'b1}},aa[P-1:0]}; ck("rep0",r32==aa);
r={4{8'(fn(2))}}; ck("rep1",r==32'h02020202&&cnt==1);
s={h," ","world"}; s2={n{"boo "}}; ck("str",s=="hello world"&&s2=="boo boo boo ");
x=5;y=7;z=5; ck("in1",x inside {y,z}&&!(x inside {y,8}));
ck("in2",4 inside {1,2,ia}&&!(6 inside {1,2,ia}));
ck("in3",3'b101 inside {3'b1?1}&&3'b1x1 inside {3'b1?1}&&(3'bz11 inside {3'b1?1,3'b011})===1'bx);
ck("in4",5 inside {[3:7]}&&!(8 inside {[3:7]})&&!(5 inside {[7:3]})&&100 inside {[50:$]});
r={>>{j}}; ck("s1",r==j);
r={<<byte{j}}; ck("s2",r==32'h44434241);
r={<<16{j}}; ck("s3",r==32'h43444142);
r8={<<{8'b0011_0101}}; ck("s4",r8==8'b1010_1100);
r6={<<4{6'b11_0101}}; ck("s5",r6==6'b010111);
r6={>>4{6'b11_0101}}; ck("s6",r6==6'b110101);
r4={<<2{{<<{4'b1101}}}}; ck("s7",r4==4'b1110);
{>>{ua,ub,uc}}=96'b1; ck("u1",ua==0&&ub==0&&uc==1);
{>>{ua,ub,uc}}=100'b11111; ck("u2",ua==0&&ub==0&&uc==1);
up[3]=1;up[2]=2;up[1]=3;up[0]=4; {>>{p1,p2,p3,p4}}={up[3],up[2],up[1],up[0]}; ck("u3",p1==1&&p4==4);
qb={<<byte{w1}}; ck("le",qb.size()==4&&qb[0]==8'h44&&qb[3]==8'h11);
{<<byte{x}}=qb; ck("le_u",x==w1);
qq={>>{arr with [0+:2]}}; ck("with",qq.size()==2&&qq[1]==2);
$display("RESULT pass=%0d fail=%0d",p,f); end endmodule
