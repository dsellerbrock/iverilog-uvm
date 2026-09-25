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
module top; initial begin delay_cfg cfg=new; if (!cfg.randomize()) $fatal(1,"randomize failed"); $display("PASS standalone z=%0d max=%0d",cfg.zero_delays,cfg.host_delay_max); $finish; end endmodule
