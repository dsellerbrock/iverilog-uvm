class delay_cfg;
  rand bit zero_delays;
  rand bit [3:0] host_delay_max;
  constraint zero_delays_c { zero_delays dist {1'b0 := 7, 1'b1 := 3}; }
  constraint host_delay_max_c {
    solve zero_delays before host_delay_max;
    if (zero_delays) host_delay_max == 0;
    else host_delay_max dist {[1:3] :/ 1};
  }
endclass
class env_cfg; rand delay_cfg child; endclass
module top; initial begin env_cfg cfg=new; cfg.child=new; if (cfg.randomize()) $display("PASS nested_one z=%0d max=%0d",cfg.child.zero_delays,cfg.child.host_delay_max); else $display("FAIL nested_one"); $finish; end endmodule
