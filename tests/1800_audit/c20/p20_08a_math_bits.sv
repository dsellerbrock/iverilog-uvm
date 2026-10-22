module p20f;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
function bit near(real a, real b); return (a-b<1e-9)&&(b-a<1e-9); endfunction
localparam int CL=$clog2(1025); localparam real SQ=$sqrt(9.0); localparam int W=$clog2(8);
logic [7:0] v8=8'b1x0z_1100; logic [15:0] big=16'h0100; int i0=0; bit [3:0] ctl; logic [1:0] bad;
initial begin
 ck("clog2",$clog2(0)==0&&$clog2(1)==0&&$clog2(2)==1&&$clog2(3)==2&&$clog2(8)==3&&$clog2(9)==4&&$clog2(1024)==10&&$clog2(1025)==11);
 ck("clog2_wide",$clog2(64'h1_0000_0000)==32&&$clog2(big)==8); ck("clog2_const",CL==11&&W==3);
 ck("math1",near($ln(1.0),0.0)&&near($log10(1000.0),3.0)&&near($exp(0.0),1.0)&&near($sqrt(16.0),4.0)&&near($pow(2.0,10.0),1024.0));
 ck("math2",near($floor(2.7),2.0)&&near($ceil(2.1),3.0)&&near($floor(-2.1),-3.0)&&near($ceil(-2.7),-2.0));
 ck("trig",near($sin(0.0),0.0)&&near($cos(0.0),1.0)&&near($tan(0.0),0.0)&&near($asin(1.0),1.5707963267948966)&&near($acos(1.0),0.0)&&near($atan(1.0),0.7853981633974483));
 ck("atan2_hypot",near($atan2(1.0,1.0),0.7853981633974483)&&near($atan2(0.0,-1.0),3.141592653589793)&&near($hypot(3.0,4.0),5.0));
 ck("hyper",near($sinh(0.0),0.0)&&near($cosh(0.0),1.0)&&near($tanh(0.0),0.0)&&near($asinh(0.0),0.0)&&near($acosh(1.0),0.0)&&near($atanh(0.0),0.0));
 ck("math_const",near(SQ,3.0));
 ck("countbits",$countbits(v8,'1)==3&&$countbits(v8,'1,'0)==6&&$countbits(v8,'x,'z)==2&&$countbits(v8,'x,'x,'z)==2);
 ck("countones",$countones(v8)==3&&$countones(8'b1111_0000)==4);
 ck("onehot",$onehot(8'b0001_0000)===1'b1&&$onehot(8'b0011_0000)===1'b0&&$onehot(8'b0)===1'b0);
 ck("onehot0",$onehot0(8'b0)===1'b1&&$onehot0(8'b0100_0000)===1'b1&&$onehot0(8'b0110_0000)===1'b0);
 ck("isunknown",$isunknown(v8)===1'b1&&$isunknown(8'hA5)===1'b0);
 ck("onehot_x",$onehot(8'b0x01_0000)===1'b1);
 ctl[0]=1'bx; ctl[1]=1'bz; ck("var_ctl",$countbits(v8,ctl[0],ctl[1])==2);
 ck("types",$bits($countbits(v8,'1))==32&&$bits($onehot(v8))==1&&$bits($countones(v8))==32);
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
