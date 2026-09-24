class csrng_like_agent_cfg;
  rand bit zero_delays;
  rand bit [3:0] host_delay_max;

  constraint zero_delays_c { zero_delays dist {1'b0 := 7, 1'b1 := 3}; }
  constraint host_delay_max_c {
    solve zero_delays before host_delay_max;
    if (zero_delays) {
      host_delay_max == 0;
    } else {
      host_delay_max dist {[1:3] :/ 1};
    }
  }
endclass

class csrng_like_env_cfg;
  rand csrng_like_agent_cfg entropy_cfg;
  rand csrng_like_agent_cfg aes_halt_cfg;
  constraint same_delay_mode_c { entropy_cfg.zero_delays == aes_halt_cfg.zero_delays; }
endclass

module top;
  initial begin
    csrng_like_env_cfg cfg;
    cfg = new;
    cfg.entropy_cfg = new;
    cfg.aes_halt_cfg = new;
    if (cfg.randomize()) $fatal(1, "expected the current joint conditional-dist RED");
    $display("PASS reproduced joint conditional-dist RED");
    $finish;
  end
endmodule
