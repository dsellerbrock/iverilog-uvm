typedef struct {
  randc bit [1:0] singleton[0:0];
  randc bit [1:0] multi[1:0];
} randc_subset_member_arrays_t;

class randc_subset_holder;
  rand randc_subset_member_arrays_t cfg;
  bit reject;
  constraint subset {
    foreach (cfg.singleton[i]) cfg.singleton[i] inside {[0:2]};
    foreach (cfg.multi[i]) cfg.multi[i] inside {[0:2]};
  }
  constraint fail_one {
    reject -> cfg.singleton[0] == 0;
    reject -> cfg.singleton[0] == 1;
  }
endclass

module test;
  initial begin
    static randc_subset_holder h = new;
    bit [2:0] seen_single, seen_multi0, seen_multi1;
    bit [1:0] save_single, save_multi0, save_multi1;
    h.reject = 0;
    repeat (2) begin
      seen_single = 0;
      seen_multi0 = 0;
      seen_multi1 = 0;
      repeat (3) begin
        if (!h.randomize()) $fatal(1, "subset randc randomize failed");
        if (h.cfg.singleton[0] > 2 || h.cfg.multi[0] > 2 || h.cfg.multi[1] > 2)
          $fatal(1, "subset randc selected excluded value");
        if (seen_single[h.cfg.singleton[0]]
            || seen_multi0[h.cfg.multi[0]]
            || seen_multi1[h.cfg.multi[1]])
          $fatal(1, "subset randc repeated within feasible cycle");
        seen_single[h.cfg.singleton[0]] = 1;
        seen_multi0[h.cfg.multi[0]] = 1;
        seen_multi1[h.cfg.multi[1]] = 1;
        if (seen_single != 3'b001 && seen_single != 3'b010
            && seen_single != 3'b100) begin
          save_single = h.cfg.singleton[0];
          save_multi0 = h.cfg.multi[0];
          save_multi1 = h.cfg.multi[1];
          h.reject = 1;
          if (h.randomize()) $fatal(1, "interleaved contradiction succeeded");
          if (h.cfg.singleton[0] !== save_single
              || h.cfg.multi[0] !== save_multi0
              || h.cfg.multi[1] !== save_multi1)
            $fatal(1, "interleaved failure changed randc member arrays");
          h.reject = 0;
        end
      end
      if (seen_single !== 3'b111 || seen_multi0 !== 3'b111
          || seen_multi1 !== 3'b111)
        $fatal(1, "subset randc feasible cycle incomplete");
    end
    $display("PASS member-array-randc-subset-two-cycles");
  end
endmodule
