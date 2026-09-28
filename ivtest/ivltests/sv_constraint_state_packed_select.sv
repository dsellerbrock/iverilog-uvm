// IEEE 1800-2017 18.3/18.8: selected class state uses its current value,
// including OpenTitan AES enabled-bit and error_types packed-slice guards.
typedef enum bit [3:0] { E0 = 0, E8 = 8 } flags_e;
typedef struct packed { bit lc_esc, reset, mal_inject, cfg; } error_types_t;

class packed_state;
  bit [2:0] enabled = 3'b110;
  bit [3:0] select_index = 7;
  flags_e mode = E8;
  error_types_t error_types = 4'b1111;
  rand bit [3:0] choice;
  rand bit cfg_seen;
  constraint c {
    if (enabled[0]) choice[0] == 1; else choice[0] == 0;
    if (mode[3]) choice[1] == 1; else choice[1] == 0;
    if (|error_types[3:1]) choice[2] == 1; else choice[2] == 0;
    if (error_types[0]) cfg_seen == 1; else cfg_seen == 0;
    if (error_types != 0) choice[2] == 1;
    if (enabled[select_index]) choice[3] == 1; else choice[3] == 0;
  }
endclass

class packed_rand;
  rand error_types_t error_types;
  constraint c { error_types == 4'b0101; }
endclass

class stopped_state;
  rand bit [3:0] mask = 4'b1000;
  rand bit selected;
  constraint c { if (mask[3]) selected == 1; else selected == 0; }
endclass

module top;
  packed_state s;
  packed_rand r;
  stopped_state p;
  initial begin
    s = new;
    if (!s.randomize() || s.choice !== 4'b0110 || s.cfg_seen !== 1)
      $fatal(1, "first state");
    s.enabled = 3'b111;
    s.mode = E0;
    s.error_types = 0;
    if (!s.randomize() || s.choice !== 4'b0001 || s.cfg_seen !== 0)
      $fatal(1, "changed state");
    r = new;
    if (!r.randomize() || r.error_types !== 4'b0101) $fatal(1, "whole struct width");
    p = new;
    p.mask.rand_mode(0);
    if (!p.randomize() || p.selected !== 1 || p.mask !== 4'b1000)
      $fatal(1, "pinned rand mode state");
    p.mask = 0;
    if (!p.randomize() || p.selected !== 0 || p.mask !== 0)
      $fatal(1, "changed pinned state");
    $display("PASSED");
  end
endmodule
