// Issue #2732: `$' is the last index of a queue anywhere in an index or slice
// bound expression (IEEE 1800-2017/2023 7.10.1: "In a queue slice expression
// such as Q[a:b], the slice bounds may be arbitrary integral expressions").
package issue2732_pkg; int pq[$] = {7, 8, 9}; endpackage

module test;
  class holder; int q[$]; endclass
  holder h;
  int q[$], r[$], s[$], x;
  int qq[$][$];
  bit failed = 0;

  task check_int(input string tag, input int got, input int want);
    if (got !== want) begin
      $display("FAILED %s: got %0d, want %0d", tag, got, want);
      failed = 1;
    end
  endtask

  task check_q(input string tag, input int got[$], input int want[$]);
    if (got != want) begin
      $display("FAILED %s: got %p, want %p", tag, got, want);
      failed = 1;
    end
  endtask

  initial begin
    q = {1, 2, 3, 4};
    // Slice bounds with `$' on the left.
    check_q("q[$-1:$]", q[$-1:$], '{3, 4});
    check_q("q[$:$]", q[$:$], '{4});
    check_q("q[0+$-2:$]", q[0+$-2:$], '{2, 3, 4});
    check_q("q[-2+$:$]", q[-2+$:$], '{2, 3, 4});
    check_q("q[$-1:$-1]", q[$-1:$-1], '{3});
    // `$-a+b' is ($-a)+b in a right bound too.
    check_q("q[0:$-1+1]", q[0:$-1+1], '{1, 2, 3, 4});
    check_q("q[1:$]", q[1:$], '{2, 3, 4});
    // Any integral index expression.
    check_int("q[$-($/2)]", q[$-($/2)], 3);
    check_int("q[$/2]", q[$/2], 2);
    check_int("q[($>2)?$-2:0]", q[($>2)?$-2:0], 2);
    check_int("q[$-1+0*$]", q[$-1+0*$], 3);
    check_int("q[$]", q[$], 4);
    check_int("q[$-1]", q[$-1], 3);
    check_int("q[$+0]", q[$+0], 4);
    // Write through an index holding `$'.
    s = q;
    s[$-1] = 30; s[$/2] = 20;
    check_q("writes", s, '{1, 20, 30, 4});
    // Each `$' belongs to the innermost queue index around it.
    r = {10, 20, 30, 40};
    check_int("nested", r[q[$] + $ - 6], 20);
    check_int("nested $-1", r[q[$-1] + $/3 - 2], 30);
    // A class member and a package queue.
    h = new; h.q = {5, 6, 7, 8};
    check_int("member", h.q[$/2], 6);
    check_q("member slice", h.q[$-2:$], '{6, 7, 8});
    check_int("package", issue2732_pkg::pq[$-1], 8);
    check_int("package $/2", issue2732_pkg::pq[$/2], 8);
    // Queues of queues: each dimension has its own `$'.
    qq = '{'{1, 2, 3}, '{4, 5}};
    check_int("qq[$][$-1]", qq[$][$-1], 4);
    check_int("qq[$-1][$/2]", qq[$-1][$/2], 2);
    if (!failed) $display("PASSED");
  end
endmodule
