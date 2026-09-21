// Control for the member-element path without a foreach header.
// IEEE 1800-2017/2023 18.4, 18.5 and 18.8.
typedef struct {
  int plain[3:2];
  rand int random_word[3:2];
} explicit_member_arrays_t;

class explicit_member_element_control;
  rand explicit_member_arrays_t cfg;
  bit make_unsat;

  constraint selected_elements {
    cfg.random_word[2] inside {[10:20]};
    cfg.random_word[3] inside {[10:20]};
    make_unsat -> cfg.random_word[3] == 10;
    make_unsat -> cfg.random_word[3] == 11;
  }
endclass

module explicit_member_element_control_test;
  initial begin
    static explicit_member_element_control item = new;
    int saved_two, saved_three;
    item.cfg.plain[2] = 222;
    item.cfg.plain[3] = 333;
    if (!item.randomize()) $fatal(1, "initial explicit member randomize failed");
    saved_two = item.cfg.random_word[2];
    item.cfg.random_word[2].rand_mode(0);
    if (!item.randomize() || item.cfg.random_word[2] !== saved_two)
      $fatal(1, "explicit selected member rand_mode failed");
    saved_three = item.cfg.random_word[3];
    item.make_unsat = 1;
    if (item.randomize()) $fatal(1, "explicit member contradiction succeeded");
    if (item.cfg.plain[2] !== 222 || item.cfg.plain[3] !== 333
        || item.cfg.random_word[2] !== saved_two
        || item.cfg.random_word[3] !== saved_three)
      $fatal(1, "explicit member failure did not roll back state");
    $display("PASS explicit-member-element-control");
  end
endmodule
