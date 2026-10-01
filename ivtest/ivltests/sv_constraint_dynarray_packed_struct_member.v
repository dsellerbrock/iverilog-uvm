// A packed-struct member of an element of a rand dynamic array is a
// constrainable solver variable, by constant index and in a foreach over the
// array (IEEE 1800-2017 18.5.8; 1800-2023 18.5.7). The constraint used to be
// reported as not representable and randomize() of the class failed.
typedef enum bit { COND_IN = 0, COND_OUT = 1 } cond_e;
typedef struct packed {
  cond_e cond;
  int    min_v;
  int    max_v;
  bit    en;
  bit signed [7:0] delta;
} cfg_t;

class dyn_cfg;
  rand cfg_t items[];
  constraint size_c { items.size() == 5; }
  constraint member_c {
    foreach (items[i]) {
      items[i].min_v inside {[10 : 100]};
      items[i].max_v >= items[i].min_v + 5;
      items[i].max_v <= 200;
      items[i].delta inside {[-3 : 3]};
    }
    items[1].en == 1;
    items[2].cond == COND_OUT;
    items[3].min_v == 42;
  }
endclass

class dyn_conflict;
  rand cfg_t items[];
  constraint size_c { items.size() == 2; }
  constraint conflict_c {
    foreach (items[i]) items[i].min_v inside {[0 : 10]};
    items[0].min_v == 50;
  }
endclass

module main;
  int errors;

  initial begin
    automatic dyn_cfg c = new;
    automatic dyn_conflict bad = new;
    automatic bit saw_neg, saw_pos, saw_out, saw_in;

    for (int n = 0; n < 40; n++) begin
      if (!c.randomize()) begin $display("FAILED randomize %0d", n); errors++; break; end
      if (c.items.size() != 5) begin $display("FAILED size %0d", c.items.size()); errors++; end
      foreach (c.items[i]) begin
        if (!(c.items[i].min_v >= 10 && c.items[i].min_v <= 100)) begin
          $display("FAILED min_v[%0d]=%0d", i, c.items[i].min_v); errors++;
        end
        if (!(c.items[i].max_v >= c.items[i].min_v + 5 && c.items[i].max_v <= 200)) begin
          $display("FAILED max_v[%0d]=%0d min_v=%0d", i, c.items[i].max_v, c.items[i].min_v); errors++;
        end
        if (!(c.items[i].delta >= -3 && c.items[i].delta <= 3)) begin
          $display("FAILED delta[%0d]=%0d", i, c.items[i].delta); errors++;
        end
        if (c.items[i].delta < 0) saw_neg = 1;
        if (c.items[i].delta > 0) saw_pos = 1;
        if (c.items[i].cond == COND_OUT) saw_out = 1; else saw_in = 1;
      end
      if (c.items[1].en != 1) begin $display("FAILED items[1].en"); errors++; end
      if (c.items[2].cond != COND_OUT) begin $display("FAILED items[2].cond"); errors++; end
      if (c.items[3].min_v != 42) begin $display("FAILED items[3].min_v=%0d", c.items[3].min_v); errors++; end
    end
    // Unconstrained members still vary: the slices must not pin the others.
    if (!(saw_neg && saw_pos && saw_out && saw_in)) begin
      $display("FAILED no variation neg=%0b pos=%0b out=%0b in=%0b", saw_neg, saw_pos, saw_out, saw_in);
      errors++;
    end

    if (bad.randomize()) begin $display("FAILED contradictory member constraint solved"); errors++; end

    if (errors == 0) $display("PASSED");
  end
endmodule
