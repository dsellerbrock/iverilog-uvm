// IEEE 1800-2017/2023 16.7: a parameter is a legal exact cycle delay.
module delay_checker #(parameter D=1)(input clk,a,q);
 integer p=0,f=0;
 assert property (@(posedge clk) a |-> q ##D q) p++; else f++;
endmodule
module sv_assert_cycle_delay_composition_fail;
 reg clk=0;
 reg a0=0,q0=0,a1=0,q1=0,a2=0,q2=0;
 delay_checker #(.D(0)) zero(clk,a0,q0);
 delay_checker default_delay(clk,a1,q1);
 delay_checker #(.D(2)) override_delay(clk,a2,q2);
 task tick; #5 clk=1; #1 clk=0; endtask
 initial begin
  // ##0 checks both sequence elements on the same sampled tick.
  a0=1; q0=1;
  // The default parameter and instance override resolve on different ticks.
  a1=1; q1=1;
  a2=1; q2=1;
  tick();
  if(zero.p!=1 || zero.f || default_delay.p || default_delay.f
     || override_delay.p || override_delay.f)
   $fatal(1,"initial cycle-delay timing");

  a0=0; q0=0;
  a1=0; q1=0;
  a2=0; q2=0;
  tick();
  if(default_delay.p!=1 || default_delay.f!=1
     || override_delay.p!=1 || override_delay.f)
   $fatal(1,"default delay did not resolve at one tick");

  q2=1;
  tick();
  if(override_delay.p!=3 || override_delay.f)
   $fatal(1,"overridden delay did not resolve at two ticks");

  // A false first q fails immediately, including for ##0.
  a0=1; a1=1; a2=1; q2=0;
  tick();
  if(zero.f!=1 || default_delay.f!=2 || override_delay.f!=1)
   $fatal(1,"false first sequence element was not checked");
  a0=0; a1=0;

  // Two starts on adjacent ticks create independent overlapping matches.
  a2=1; q2=1;
  tick();
  a2=1;
  tick();
  a2=0;
  tick();
  tick();
  if(override_delay.p!=7 || override_delay.f!=1)
   $fatal(1,"overlapping delayed sequence attempts");
  $display("PASSED");
 end
endmodule
