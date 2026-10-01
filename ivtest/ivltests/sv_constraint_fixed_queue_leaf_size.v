// Indexed queue sizes are separate variables for each fixed-array word.
typedef struct packed { bit [3:0] en, start_page; } page_t;

class bounds_case;
  rand bit q[2:3][5:3][$];
  constraint sizes {
    foreach (q[i,j]) q[i][j].size() == 1 + 3*(i-2) + (5-j);
  }
endclass

class packed_case;
  rand page_t q[2][$];
  constraint sizes { foreach (q[i]) q[i].size() == i + 1; }
endclass

class mode_case;
  rand bit q[2][$];
  constraint sizes { q[0].size() == 1; q[1].size() == 2; }
endclass

class single_case;
  rand bit q[0:0][$];
  constraint sizes { q[0].size == 3; }
endclass

class state_case;
  rand int x;
  bit q[2][$];
  constraint value { x == q[1].size(); }
endclass

class function_case;
  rand bit q[2][$];
  function automatic int plus_one(input int n);
    return n + 1;
  endfunction
  constraint sizes {
    q[1].size() == 1;
    q[0].size() == plus_one(q[1].size());
  }
endclass

module test;
  int errors = 0;
  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      errors++;
    end
  endtask
  initial begin
    automatic bounds_case b = new;
    automatic packed_case p = new;
    automatic mode_case m = new;
    automatic single_case one = new;
    automatic state_case s = new;
    automatic function_case f = new;

    check("nonzero descending bounds", b.randomize() &&
      b.q[2][5].size() == 1 && b.q[2][4].size() == 2 &&
      b.q[2][3].size() == 3 && b.q[3][5].size() == 4 &&
      b.q[3][4].size() == 5 && b.q[3][3].size() == 6);

    check("packed queue sizes", p.randomize() &&
      p.q[0].size() == 1 && p.q[1].size() == 2);
    p.q[1][1] = 8'ha5;
    check("packed queue word", p.q[1][1].en == 4'ha &&
      p.q[1][1].start_page == 4'h5);

    m.q[0] = '{1, 0, 1};
    m.q[1] = '{1, 0};
    m.q[1].rand_mode(0);
    check("disabled sibling", m.randomize() &&
      m.q[0].size() == 1 && m.q[1].size() == 2);
    m.q[1] = '{1, 0, 1, 0};
    check("disabled leaf conflict", !m.randomize() &&
      m.q[0].size() == 1 && m.q[1].size() == 4);
    m.q[1].rand_mode(1);
    m.q.rand_mode(0);
    check("whole property disabled", !m.randomize() &&
      m.q[0].size() == 1 && m.q[1].size() == 4);

    one.q[0] = '{1, 0};
    check("one-word array and paren-less size", one.randomize() &&
      one.q[0].size() == 3);

    s.q[0] = '{1};
    s.q[1] = '{1, 0, 1};
    check("non-rand selected state", s.randomize() && s.x == 3 &&
      s.q[0].size() == 1 && s.q[1].size() == 3);

    check("function argument leaf identity", f.randomize() &&
      f.q[0].size() == 2 && f.q[1].size() == 1);

    if (errors == 0) $display("PASSED");
    else $display("FAILED -- %0d errors", errors);
  end
endmodule
