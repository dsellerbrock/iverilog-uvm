class standalone_conditional_dist;
  rand bit zero_delays;
  rand bit [3:0] host_delay_max;
  constraint zero_delays_c { zero_delays dist {1'b0 := 7, 1'b1 := 3}; }
  constraint host_delay_max_c {
    solve zero_delays before host_delay_max;
    if (zero_delays) host_delay_max == 0;
    else host_delay_max dist {[1:3] :/ 1};
  }
endclass

module top;
  initial begin
    standalone_conditional_dist cfg;
    cfg = new;
    repeat (8) begin
      if (!cfg.randomize()) $fatal(1, "single-owner conditional dist should solve");
      if (cfg.zero_delays ? (cfg.host_delay_max != 0)
                          : (cfg.host_delay_max < 1 || cfg.host_delay_max > 3))
        $fatal(1, "conditional dist branch produced an illegal value");
    end
    $display("PASS standalone conditional dist boundary");
    $finish;
  end
endmodule
