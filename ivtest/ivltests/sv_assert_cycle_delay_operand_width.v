// IEEE 16.7,16.8: grouped delay offsets preserve argument width/sign.
module delay_width_checker #(parameter D=0, parameter logic [3:0] X=15,
 parameter logic signed [3:0] Y=4'sh8)(input clk,a,q);
 integer p=0,r=0,u0=0,u1=0,s0=0,s1=0;
 property unsigned_delay(D); @(posedge clk) a |-> ##D (##2 q); endproperty
 property signed_delay(D); @(posedge clk) a |-> ##D (##2 q); endproperty
 assert property (unsigned_delay(X+4'd1)) p++;
 assert property (signed_delay(Y-4'sd1)) r++;
 property plain_overlap(D); @(posedge clk) a |-> ##D q; endproperty
 property plain_nonoverlap(D); @(posedge clk) a |=> ##D q; endproperty
 assert property (plain_overlap(X+4'd1)) u0++;
 assert property (plain_nonoverlap(X+4'd1)) u1++;
 assert property (plain_overlap(Y-4'sd1)) s0++;
 assert property (plain_nonoverlap(Y-4'sd1)) s1++;
endmodule
module sv_assert_cycle_delay_operand_width;
 reg clk=0,a=1,q=1;delay_width_checker u(clk,a,q);
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  tick();$assertoff(0);
  if(u.u0!=1||u.u1||u.s0||u.s1) $fatal(1,"plain overlap width");
  tick();
  if(u.u1!=1||u.s0||u.s1) $fatal(1,"plain nonoverlap width");
  tick();
  if(u.p!=1||u.r) $fatal(1,"unsigned delay arithmetic widened");
  repeat(5)tick();
  if(u.s0!=1||u.s1) $fatal(1,"signed overlap width");
  tick();
  if(u.s1!=1) $fatal(1,"signed nonoverlap width");
  tick();
  if(u.p!=1||u.r!=1) $fatal(1,"signed delay arithmetic widened");
  $display("PASSED");
 end
endmodule
