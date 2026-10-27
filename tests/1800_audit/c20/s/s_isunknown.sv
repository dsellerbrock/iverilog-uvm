module p20f;
int p=0,f=0; task automatic ck(input string i,input bit c); if(c)p++; else begin f++;$display("FAIL %s",i); end endtask
function bit near(real a, real b); return (a-b<1e-9)&&(b-a<1e-9); endfunction
localparam int CL=$clog2(1025); localparam real SQ=$sqrt(9.0); localparam int W=$clog2(8);
logic [7:0] v8=8'b1x0z_1100; logic [15:0] big=16'h0100; int i0=0; bit [3:0] ctl; logic [1:0] bad;
initial begin
 ck("isunknown",$isunknown(v8)===1'b1&&$isunknown(8'hA5)===1'b0);
 $display("RESULT pass=%0d fail=%0d",p,f); end endmodule
