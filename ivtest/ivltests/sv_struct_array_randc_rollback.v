typedef struct {
  randc bit [1:0] cyclic[0:0];
} randc_member_array_t;

class randc_member_array_holder;
  rand randc_member_array_t cfg;
  bit reject;
  constraint legal { foreach (cfg.cyclic[i]) cfg.cyclic[i] inside {[0:3]}; }
  constraint fail_one { reject -> cfg.cyclic[0] == 0; reject -> cfg.cyclic[0] == 1; }
endclass

module test;
  initial begin
    static randc_member_array_holder h = new;
    static bit [3:0] seen = 0;
    bit [1:0] before_fail;
    h.reject = 0;
    repeat (2) begin
      if (!h.randomize()) $fatal(1, "randc member-array randomize failed");
      if (seen[h.cfg.cyclic[0]]) $fatal(1, "randc repeated before cycle");
      seen[h.cfg.cyclic[0]] = 1;
    end
    before_fail = h.cfg.cyclic[0];
    h.reject = 1;
    if (h.randomize()) $fatal(1, "contradictory randc solve succeeded");
    if (h.cfg.cyclic[0] !== before_fail) $fatal(1, "failed solve changed value");
    h.reject = 0;
    repeat (2) begin
      if (!h.randomize()) $fatal(1, "randc member-array retry failed");
      if (seen[h.cfg.cyclic[0]]) $fatal(1, "failed solve corrupted randc history");
      seen[h.cfg.cyclic[0]] = 1;
    end
    if (seen !== 4'b1111) $fatal(1, "randc cycle incomplete: %b", seen);
    $display("PASS member-array-randc-cycle-rollback");
  end
endmodule
