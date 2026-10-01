// A function called in a constraint may take, besides random variables, state
// read through a non-rand object handle of the class (cfg.period,
// cfg.sub.scale). That state is sampled when the call is evaluated; it is not
// a random variable of the class, so it must not make the call
// unrepresentable (IEEE 1800-2017 18.5.12; 1800-2023 18.5.11). OpenTitan's
// i2c host perf sequence passes cfg.clk_rst_vif.clk_period_ps this way.
typedef enum { SLOW, MID, FAST } speed_e;

class sub_cfg;
  int unsigned scale = 3;
endclass

class seq_cfg;
  function int get_min(speed_e m, int unsigned period, int unsigned scale);
    case (m)
      SLOW: return 4000 / period + scale;
      MID:  return 600 / period + scale;
      default: return 260 / period + scale;
    endcase
  endfunction
endclass

class env_cfg;
  int unsigned period = 20;
  sub_cfg sub;
  seq_cfg seq;
  function new();
    sub = new;
    seq = new;
  endfunction
endclass

class vseq;
  env_cfg cfg;
  rand speed_e mode;
  rand int thd;
  constraint c {
    thd == cfg.seq.get_min(mode, cfg.period, cfg.sub.scale);
  }
endclass

module main;
  int errors;
  initial begin
    automatic vseq v = new;
    automatic bit seen_slow, seen_mid, seen_fast;
    v.cfg = new;

    for (int n = 0; n < 30; n++) begin
      if (!v.randomize()) begin $display("FAILED randomize %0d", n); errors++; break; end
      if (v.thd != v.cfg.seq.get_min(v.mode, v.cfg.period, v.cfg.sub.scale)) begin
        $display("FAILED mode=%0d thd=%0d", v.mode, v.thd); errors++;
      end
      case (v.mode) SLOW: seen_slow = 1; MID: seen_mid = 1; default: seen_fast = 1; endcase
    end
    if (!(seen_slow && seen_mid && seen_fast)) begin
      $display("FAILED mode did not vary"); errors++;
    end

    // The sampled state follows the object between calls.
    v.cfg.period = 40;
    v.cfg.sub.scale = 9;
    void'(v.randomize());
    if (v.thd != v.cfg.seq.get_min(v.mode, 40, 9)) begin
      $display("FAILED after state change mode=%0d thd=%0d", v.mode, v.thd); errors++;
    end

    // A null receiver handle is not a value; randomize() must fail.
    v.cfg = null;
    if (v.randomize()) begin $display("FAILED null handle solved"); errors++; end

    if (errors == 0) $display("PASSED");
  end
endmodule
