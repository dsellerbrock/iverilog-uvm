// IEEE 6.8 Table6-7,6.21,9.4.2: each invocation starts with its own defaults.
module sv_automatic_integral_default_events;
 integer done=0;
 task automatic bit_edges();
  bit [3:0] value;
  time origin;
  origin=$time;
  begin
   integer wakes=0;
   fork
    begin @(negedge value[0]);if($time-origin!=3)$fatal(1,"false default negedge");wakes++;end
    begin @(posedge value[0]);if($time-origin!=2)$fatal(1,"missing initial zero");wakes++;end
    begin #1;value=0;value[2:1]=0;#1;value[0]=1;#1;value[0]=0;end
   join
   if(wakes!=2)$fatal(1,"lost default edge");
  end
  done++;
 endtask
 task automatic logic_edges(input bit rising);
  logic value;
  time origin;
  origin=$time;
  fork
   begin
    if(rising)@(posedge value);else @(negedge value);
    if($time-origin!=1)$fatal(1,"four-state default edge");
   end
   begin #1;value=rising;end
  join
  done++;
 endtask
 initial begin
  repeat(3) begin
   fork bit_edges();begin #1;bit_edges();end join
   fork logic_edges(0);logic_edges(1);join
  end
  if(done!=12)$fatal(1,"activation count");
  $display("PASSED");$finish(0);
 end
 initial begin #100;$fatal(1,"missing activation edge");end
endmodule
