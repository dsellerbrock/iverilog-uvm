// G18 (Phase 66): inside {enum_set} constraint — excluded values not picked
// Tests that `c inside {RED, BLUE, MAGENTA}` rejects GREEN and YELLOW.
typedef enum int { RED=0, GREEN=1, BLUE=2, YELLOW=3, MAGENTA=4 } color_t;

class Foo;
  rand color_t c;
  constraint pick_some { c inside {RED, BLUE, MAGENTA}; }
endclass

module top;
  Foo f;
  int ok, fail;
  initial begin
    f = new; ok = 0; fail = 0;
    repeat (30) begin
      void'(f.randomize());
      if (f.c == RED || f.c == BLUE || f.c == MAGENTA) ok++;
      else begin
        fail++;
        $display("  excluded value picked: %s (%0d)", f.c.name(), f.c);
      end
    end
    if (fail == 0)
      $display("PASS: inside {enum_set} excludes unwanted values (%0d ok)", ok);
    else
      $display("FAIL: %0d excluded values picked, %0d correct", fail, ok);
    $finish;
  end
endmodule
