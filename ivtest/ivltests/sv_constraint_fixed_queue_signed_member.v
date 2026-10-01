typedef struct packed { logic signed [3:0] s; logic [1:0] u; } signed_entry_t;
class S;
  rand signed_entry_t q[1][$];
  constraint c {
    q[0].size() == 1;
    q[0][0].s < 0;
    q[0][0].s == -2;
    q[0][0].u == 2;
  }
endclass
module test;
  S s;
  initial begin
    s = new;
    if (!s.randomize()) $fatal(1, "signed solve failed");
    if (s.q[0].size() != 1 || s.q[0][0].s != -2 || s.q[0][0].u != 2)
      $fatal(1, "signed value mismatch");
    $display("PASSED");
  end
endmodule
