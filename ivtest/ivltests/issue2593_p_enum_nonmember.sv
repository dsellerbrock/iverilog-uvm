// IEEE 1800-2017/2023 21.2.1.7: under %p an enumerated value prints its
// member name, and a value that names no member prints the value. Members
// of a packed struct next to an enum member keep their own values.
module issue2593_p_enum_nonmember;
  typedef enum {ON, OFF} e_t;
  typedef enum logic [3:0] {A = 4'd2, B = 4'd9} n_t;
  e_t bad, good;
  n_t nb;
  e_t arr [2];
  typedef enum logic [1:0] {IDLE, RUN} st_t;
  typedef struct packed { st_t st; logic [3:0] x; } s_t;
  typedef struct packed { s_t inner; logic y; } o_t;
  s_t ps; o_t po;
  string s;
  bit ok = 1;

  task automatic expect_str(string got, string want);
    if (got != want) begin
      $display("FAILED: \"%s\", expected \"%s\"", got, want);
      ok = 0;
    end
  endtask

  initial begin
    bad = e_t'(5); good = OFF; nb = n_t'(4'd7);
    arr[0] = ON; arr[1] = e_t'(3);
    s = $sformatf("%p", bad);  expect_str(s, "5");
    s = $sformatf("%p", good); expect_str(s, "OFF");
    s = $sformatf("%p", nb);   expect_str(s, "7");
    s = $sformatf("%p %p", good, bad); expect_str(s, "OFF 5");
    s = $sformatf("%p", arr);  expect_str(s, "'{ON, 3}");
    // The enum member lookup must not disturb the struct's other members.
    ps = '{RUN, 4'h3}; po = '{ps, 1'b1};
    s = $sformatf("%p", ps); expect_str(s, "'{st:RUN, x:3}");
    s = $sformatf("%p", po); expect_str(s, "'{inner:'{st:RUN, x:3}, y:1}");
    if (ok) $display("PASSED");
  end
endmodule
