// VVP tracks exact randc cycles through 20-bit leaves. A wider member remains
// legal IEEE syntax, but its plain-rand fallback must be diagnosed by name;
// the exact 20-bit boundary is the no-warning control.
typedef struct {
  randc bit [20:0] wide_cycle;
} nested_capped_random_member_record_t;

typedef struct {
  rand nested_capped_random_member_record_t nested;
  randc bit [19:0] boundary_cycle;
} capped_random_member_record_t;

class capped_random_member_item;
  rand capped_random_member_record_t record;
endclass

module test;
  initial begin
    capped_random_member_item item;
    item = new;
    if (item.randomize() !== 1)
      $fatal(1, "nested randc cap fallback failed");
    $display("PASSED");
  end
endmodule
