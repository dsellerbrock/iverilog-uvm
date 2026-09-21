// IEEE 1800-2017/2023 18.4, 18.5 and 18.8.
typedef struct {
  int plain[3:2];
  rand int random_word[3:2];
} state_member_arrays_t;

class state_rand_mode_rollback;
  rand state_member_arrays_t cfg;
  bit make_unsat;

  constraint legal_values {
    foreach (cfg.random_word[i]) cfg.random_word[i] inside {[10:20]};
  }
  constraint contradiction {
    make_unsat -> cfg.random_word[3] == 10;
    make_unsat -> cfg.random_word[3] == 11;
  }
endclass

module state_rand_mode_rollback_test;
  initial begin
    static state_rand_mode_rollback item = new;
    int saved_two, saved_three;
    item.cfg.plain[2] = 222;
    item.cfg.plain[3] = 333;
    item.make_unsat = 0;
    if (!item.randomize()) $fatal(1, "initial member-array randomize failed");
    saved_two = item.cfg.random_word[2];
    item.cfg.random_word[2].rand_mode(0);
    if (item.cfg.random_word[2].rand_mode() !== 0)
      $fatal(1, "selected member-array rand_mode was not disabled");
    if (!item.randomize()) $fatal(1, "randomize with one disabled member failed");
    if (item.cfg.plain[2] !== 222 || item.cfg.plain[3] !== 333)
      $fatal(1, "plain member array changed during randomize");
    if (item.cfg.random_word[2] !== saved_two)
      $fatal(1, "disabled selected member-array element changed");
    saved_three = item.cfg.random_word[3];
    item.make_unsat = 1;
    if (item.randomize()) $fatal(1, "contradictory member constraint succeeded");
    if (item.cfg.plain[2] !== 222 || item.cfg.plain[3] !== 333
        || item.cfg.random_word[2] !== saved_two
        || item.cfg.random_word[3] !== saved_three)
      $fatal(1, "failed randomize did not roll back member-array state");
    $display("PASS state-rand-mode-rollback");
  end
endmodule
