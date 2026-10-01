// `x inside {a, b}' where the members are variables or state, not literals
// (IEEE 1800-2017/2023 11.4.13, 18.5.4). The solver dropped every
// non-literal member without a diagnostic, so the constraint vanished or
// narrowed to the literal members only (OpenTitan edn: a driver delay
// `cmd_ack_dly inside {cfg.min_cmd_ack_dly, cfg.max_cmd_ack_dly}' came back as
// 773251903 and the testbench waited for it).
class cfg_c;
  int unsigned min_d, max_d;
endclass

class state_inside;
  rand int unsigned p;
  int unsigned lo, hi;
  constraint c { p inside {lo, hi}; }
endclass

class chain_inside;
  rand int unsigned p;
  cfg_c cfg;
  constraint c { p inside {cfg.min_d, cfg.max_d}; }
endclass

class mixed_inside;
  rand int unsigned p;
  cfg_c cfg;
  constraint c { p inside {cfg.min_d, 7}; }
endclass

class driver;
  cfg_c cfg;
  int unsigned dly, lo, hi;
  task pick();
    if (!std::randomize(dly) with { dly inside {cfg.min_d, cfg.max_d}; })
      $display("FAILED std::randomize");
  endtask
  task pick_this();
    if (!std::randomize(this.dly) with { this.dly inside {this.lo, this.hi}; })
      $display("FAILED std::randomize this");
  endtask
  task pick_state();
    if (!std::randomize(dly) with { dly inside {lo, hi}; })
      $display("FAILED std::randomize state");
  endtask
endclass

module main;
  int errors;
  initial begin
    state_inside s;
    chain_inside ch;
    mixed_inside m;
    driver d;
    cfg_c cfg;
    int unsigned local_v;
    bit saw4, saw7;
    cfg = new; cfg.min_d = 4; cfg.max_d = 32;
    s = new; s.lo = 5; s.hi = 40;
    ch = new; ch.cfg = cfg;
    m = new; m.cfg = cfg;
    d = new; d.cfg = cfg; d.lo = 6; d.hi = 50;

    repeat (30) begin
      if (!s.randomize() || (s.p != 5 && s.p != 40)) begin
        $display("FAILED state inside p=%0d", s.p); errors++;
      end
      if (!ch.randomize() || (ch.p != 4 && ch.p != 32)) begin
        $display("FAILED chain inside p=%0d", ch.p); errors++;
      end
      if (!m.randomize() || (m.p != 4 && m.p != 7)) begin
        $display("FAILED mixed inside p=%0d", m.p); errors++;
      end
      saw4 |= m.p == 4;
      saw7 |= m.p == 7;
      d.pick();
      if (d.dly != 4 && d.dly != 32) begin
        $display("FAILED std::randomize member dly=%0d", d.dly); errors++;
      end
      d.pick_state();
      if (d.dly != 6 && d.dly != 50) begin
        $display("FAILED std::randomize state dly=%0d", d.dly); errors++;
      end
      d.pick_this();
      if (d.dly != 6 && d.dly != 50) begin
        $display("FAILED std::randomize this dly=%0d", d.dly); errors++;
      end
      void'(std::randomize(local_v) with { local_v inside {cfg.min_d, cfg.max_d}; });
      if (local_v != 4 && local_v != 32) begin
        $display("FAILED local inside v=%0d", local_v); errors++;
      end
    end
    if (!saw4 || !saw7) begin
      $display("FAILED mixed inside never chose both members"); errors++;
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
