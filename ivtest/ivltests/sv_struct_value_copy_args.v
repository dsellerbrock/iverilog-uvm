// M4B-1 / M4B-2: struct VALUE-copy semantics (IEEE 1800-2017 7.2).
// A struct is a value type: passing one by value, returning one, or
// pushing one into a queue must snapshot it, and assigning a nested
// unpacked struct must deep-copy the inner struct rather than share
// it. These were tracked as open correctness items; this test pins
// the behavior so it cannot regress silently.
module main;
  typedef struct { int x; int y; } pt_t;
  typedef struct { pt_t p; int z; } nest_t;

  function automatic void bump(pt_t a);   // by-value arg
    a.x = 999;
  endfunction

  function automatic pt_t mk();           // by-value return
    pt_t r; r.x = 1; r.y = 2; return r;
  endfunction

  pt_t q[$];
  pt_t g;
  nest_t n1, n2;
  int fails = 0;

  initial begin
    // M4B-1a: by-value arg must not alias the caller's struct
    g.x = 5; g.y = 6;
    bump(g);
    if (g.x != 5) begin $display("FAIL arg-copy: g.x=%0d (expect 5)", g.x); fails++; end

    // M4B-1b: by-value return is an independent copy
    begin pt_t a, b;
      a = mk(); b = mk(); a.x = 77;
      if (b.x != 1) begin $display("FAIL ret-copy: b.x=%0d (expect 1)", b.x); fails++; end
    end

    // M4B-1c: push_back(var) must snapshot, not alias
    g.x = 10; q.push_back(g); g.x = 20; q.push_back(g);
    if (q[0].x != 10) begin $display("FAIL push_back-copy: q[0].x=%0d (expect 10)", q[0].x); fails++; end

    // M4B-2: nested unpacked-struct deep copy
    n1.p.x = 1; n1.p.y = 2; n1.z = 3;
    n2 = n1;
    n2.p.x = 42;
    if (n1.p.x != 1) begin $display("FAIL nested-deep-copy: n1.p.x=%0d (expect 1)", n1.p.x); fails++; end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule
