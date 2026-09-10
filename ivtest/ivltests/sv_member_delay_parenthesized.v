// IEEE1800-2017/2023 9.4.1: parenthesized member delay needs no extension.
module sv_member_delay_parenthesized;
 timeunit 1ns;timeprecision 1ps;
 typedef struct {time offset;} setting_t;
 class Inner;real offset;endclass
 class Outer;Inner inner;endclass
 setting_t setting;
 Outer config_obj;
 int rhs=9,blocking_result=0,nba_result=0;
 initial begin
  setting.offset=3;
  config_obj=new;config_obj.inner=new;config_obj.inner.offset=0.25;
  #(setting.offset);
  if($realtime!=3.0)$fatal(1,"struct delay");
  #(config_obj.inner.offset);
  if($realtime!=3.25)$fatal(1,"nested real delay");
  config_obj.inner.offset=0.5;
  #(config_obj.inner.offset);
  if($realtime!=3.75)$fatal(1,"changed member delay");
  setting.offset=2;
  fork
   begin
    blocking_result = #(setting.offset) rhs;
    if($realtime!=5.75 || blocking_result!=9)$fatal(1,"blocking capture");
   end
   begin #1;rhs=17;end
  join
  nba_result <= #(config_obj.inner.offset) rhs;
  rhs=23;
  #(0.25);
  if(nba_result!=0)$fatal(1,"early NBA");
  #(0.5);
  if(nba_result!=17 || $realtime!=6.5)$fatal(1,"NBA capture/timing");
  $display("PASSED");
 end
endmodule
