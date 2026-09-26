// A class constraint may read non-random state through an object-property
// chain whose steps select array elements (IEEE 1800-2017/2023 18.3), as
// OpenTitan kmac_base_vseq.sv does with
//   cfg.m_edn_pull_agent_cfgs[0].device_delay_max
// The value is read at each randomize() call, and a null handle anywhere in
// the chain fails the call instead of reading 0.
module test;
  typedef enum bit { ModeSw, ModeEdn } mode_e;
  class agent_cfg;
    int unsigned device_delay_max = 3;
  endclass
  class env_cfg;
    bit enable_masking = 1;
    int edn_clk_freq_mhz = 100, clk_freq_mhz = 50;
    agent_cfg m_agents[2];
    agent_cfg q[$];
    function new();
      agent_cfg extra = new;
      m_agents[0] = new;
      m_agents[1] = new;
      q.push_back(extra);
    endfunction
  endclass
  class seq;
    env_cfg cfg;
    rand mode_e mode;
    rand bit timer_en;
    rand bit [9:0] prescaler_val;
    rand bit [15:0] wait_timer;
    rand bit [7:0] a, b;
    constraint entropy_period_c {
      if (mode == ModeEdn && cfg.enable_masking) {
        if (timer_en) {
          (prescaler_val + 1) * wait_timer >
            (cfg.m_agents[0].device_delay_max * 4 + 10) *
            (cfg.edn_clk_freq_mhz / cfg.clk_freq_mhz + 1);
        } else {
          wait_timer == 0;
        }
      }
      solve mode before prescaler_val, wait_timer;
    }
    constraint copy_c {
      a == cfg.m_agents[1].device_delay_max;
      b == cfg.q[0].device_delay_max + 1;
    }
  endclass

  initial begin
    automatic seq s = new;
    automatic int bad = 0;
    s.cfg = new;
    s.cfg.m_agents[0].device_delay_max = 200;
    s.cfg.m_agents[1].device_delay_max = 17;
    s.cfg.q[0].device_delay_max = 40;
    repeat (20) begin
      if (!s.randomize()) bad++;
      if (s.mode == ModeEdn && s.timer_en
          && !((s.prescaler_val + 1) * s.wait_timer > (200 * 4 + 10) * 3)) bad++;
      if (s.mode == ModeEdn && !s.timer_en && s.wait_timer != 0) bad++;
      if (s.a != 17 || s.b != 41) bad++;
    end
    s.cfg.m_agents[1].device_delay_max = 99;
    if (!s.randomize() || s.a != 99) bad++;
    s.cfg.m_agents[1] = null;
    if (s.randomize()) bad++;
    if (bad == 0) $display("PASSED");
    else $display("FAILED: %0d", bad);
  end
endmodule
