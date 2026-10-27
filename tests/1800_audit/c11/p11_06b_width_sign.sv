module p11f;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
logic [3:0] a=4'hF,m=9,n=8,c4=1; logic [4:0] d5=0; logic [5:0] b6=6'hA; logic [15:0] c16,a16=16'hFFFF,b16=1,ans;
logic [7:0] rA,rB; logic signed [7:0] rS,sb=-1,w8,w8z; logic signed [3:0] sx=4'bx000,sz=4'bz000; int w;
initial begin
ck("c_ctx",$sformatf("%b",c4?(m&n):d5)=="01000");
ans=(a16+b16)>>1; ck("lost_carry",ans==0);
ans=(a16+b16+0)>>1; ck("kept_carry",ans==16'h8000);
ck("self_mul",$sformatf("%h",a*b6)=="16");
c16={a**b6}; ck("self_pow",c16==1);
c16=a**b6; ck("ctx_pow",c16==16'hac61);
rA=$unsigned(-4); rB=$unsigned(-4'sd4); rS=$signed(4'b1100); ck("sys",rA==8'b11111100&&rB==8'b00001100&&rS==-4);
rA=unsigned'(-4); rS=signed'(4'b1100); ck("cast",rA==8'b11111100&&rS==-4);
rA=8'h80; rB=8'h80; w=rA+rB; ck("uns_add",w==256);
w=byte'(rA)+byte'(rB); ck("byte_add",w==-256);
w=$signed(rA)+$signed(rB); ck("sig_add",w==-256);
c16=sb[7:0]; ck("part_unsigned",c16==16'h00FF);
c16=sb; ck("sign_ext",c16==16'hFFFF);
c16={sb}; ck("concat_unsigned",c16==16'h00FF);
w=sb[7]; ck("bit_unsigned",w==1);
w8=sx; w8z=sz; ck("x_fill",w8===8'bxxxx_x000&&w8z===8'bzzzz_z000);
ck("x_nonlogical",(4'sb10x0+4'sd1)===4'bxxxx);
$display("RESULT pass=%0d fail=%0d",p,f); end endmodule
