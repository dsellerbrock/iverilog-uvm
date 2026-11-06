typedef struct {
  rand bit [7:0] a;
  rand bit [7:0] b;
} rec_t;

class item;
  rand rec_t r;
endclass

module main;
  initial begin
    item x;
    bit [7:0] a0, b0;
    int b_changes;

    x = new;
    x.srandom(32'h2568);
    if (!x.randomize()) $fatal(1, "initial randomize failed");
    x.r.rand_mode(0);
    x.r.b.rand_mode(1);
    if (x.r.a.rand_mode() != 0 || x.r.b.rand_mode() != 1)
      $fatal(1, "wrong member rand_mode query");

    a0 = x.r.a;
    b0 = x.r.b;
    b_changes = 0;
    repeat (20) begin
      if (!x.randomize()) $fatal(1, "randomize failed");
      if (x.r.a !== a0) $fatal(1, "inactive member a changed");
      if (x.r.b !== b0) b_changes++;
    end
    if (b_changes < 10) $fatal(1, "active member b changed only %0d times", b_changes);
    $display("ISSUE2568 struct member rand_mode PASS");
  end
endmodule
