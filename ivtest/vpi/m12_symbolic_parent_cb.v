// Endpoint multiplicity must not leak into parent callbacks. Vacuity has
// a user action but no success callback; a delayed action cannot be repeated.
module m12_symbolic_parent_cb;
 parameter LO=2,HI=3;
 reg clk=0,keep=1;
 integer p=0,f=0,v=0;
 good: assert property (@(posedge clk) keep[*LO:HI] |-> 1'b1)
   begin #20; p++; end else $fatal;
 bad: assert property (@(posedge clk) keep[*LO:HI] |-> 1'b0)
   begin $fatal; end else f++;
 vacuous: assert property (@(posedge clk) 1'b0[*LO:HI] |-> 1'b0)
   v++; else $fatal;
 task tick;#5 clk=1;#1 clk=0;endtask
 initial begin
  #1;$setup_endpoint_fanout_cb;
  tick();$assertoff(0);tick();tick();
  if(p || f!=1 || v!=1) $fatal(1,"parent verdict timing");
  #25;
  if(p!=1 || f!=1 || v!=1) $fatal(1,"parent user actions");
  $check_endpoint_fanout_cb(1,1);
 end
endmodule
