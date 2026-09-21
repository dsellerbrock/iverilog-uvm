typedef struct {
  logic plain[0:0];
  rand logic selected[0:0];
} four_state_member_array_t;

class four_state_member_array_holder;
  rand four_state_member_array_t cfg;
  bit use_plain;
  constraint guarded_state { use_plain -> cfg.selected[0] == cfg.plain[0]; }
endclass

module test;
  initial begin
    static four_state_member_array_holder h = new;
    h.use_plain = 1;
    h.cfg.plain[0] = 1'bx;
    if (h.randomize()) $fatal(1, "X state member-array leaf was accepted");
    h.use_plain = 0;
    h.cfg.selected[0].rand_mode(0);
    h.cfg.selected[0] = 1'bx;
    if (!h.randomize()) $fatal(1, "unselected X leaf poisoned guarded solve");
    if (h.cfg.selected[0] !== 1'bx) $fatal(1, "disabled X leaf changed");
    $display("PASS member-array-4state-state");
  end
endmodule
