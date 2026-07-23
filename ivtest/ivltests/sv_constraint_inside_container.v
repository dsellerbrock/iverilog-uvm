// Check (1) inside-constraints whose membership set is a queue/darray
// class property: the set must be the container's contents at
// randomize() time (state-dependent), including via inline with-clauses;
// and (2) IEEE 1800-2017 18.6.1 randomize() failure semantics: an
// unsatisfiable constraint set (empty container, contradiction) returns
// 0 and leaves the rand properties unchanged.
module main;
  class E;
    int q[$];
    rand int x;
    constraint c { x inside {q}; }
  endclass
  class M;
    int q[$];
    rand int x;
    constraint c { x inside {q, 100}; }
  endclass
  class S_;
    byte sq[$];
    rand byte x;
    constraint c { x inside {sq}; }
  endclass
  class D;
    int d[];
    rand int x;
    constraint c { x inside {d}; }
  endclass
  class W;
    int q[$];
    rand int x;
  endclass
  class K;
    rand int x;
    constraint a { x > 10; }
    constraint b { x < 5; }
  endclass

  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  initial begin
    automatic E e = new;
    automatic M m = new;
    automatic S_ s = new;
    automatic D d = new;
    automatic W w = new;
    automatic K k = new;
    automatic int ok;
    automatic bit all;

    // empty container: randomize fails, value untouched
    e.x = 12345;
    ok = e.randomize();
    check("empty-fail", ok == 0 && e.x == 12345);

    // set follows live contents
    e.q.push_back(77);
    void'(e.randomize());
    check("single", e.x == 77);
    e.q.delete(); e.q.push_back(88);
    void'(e.randomize());
    check("replaced", e.x == 88);

    // union with literal
    m.q.push_back(5);
    all = 1;
    for (int i = 0; i < 20; i++) begin
       void'(m.randomize());
       if (!(m.x == 5 || m.x == 100)) all = 0;
    end
    check("union", all);

    // signed elements
    s.sq.push_back(-3); s.sq.push_back(120);
    all = 1;
    for (int i = 0; i < 20; i++) begin
       void'(s.randomize());
       if (!(s.x == -3 || s.x == 120)) all = 0;
    end
    check("signed", all);

    // dynamic-array container
    d.d = new[2]; d.d[0] = 11; d.d[1] = 22;
    all = 1;
    for (int i = 0; i < 20; i++) begin
       void'(d.randomize());
       if (!(d.x == 11 || d.x == 22)) all = 0;
    end
    check("darray", all);

    // inline with-clause container
    w.q.push_back(9);
    all = 1;
    for (int i = 0; i < 10; i++) begin
       automatic int rr;
       rr = w.randomize() with { x inside {q}; };
       if (rr != 1 || w.x != 9) all = 0;
    end
    check("with-clause", all);

    // contradiction fails and constraint_mode recovers it
    k.x = -1;
    ok = k.randomize();
    check("contradiction-fail", ok == 0 && k.x == -1);
    k.b.constraint_mode(0);
    ok = k.randomize();
    check("mode-recover", ok == 1 && k.x > 10);

    if (!failed) $display("PASSED");
  end
endmodule
