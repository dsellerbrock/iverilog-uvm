// G10 (7.12.2): array ordering methods — sort, rsort, reverse,
// shuffle — including the shapes UVM depends on: class-property
// receivers (previously a SILENT NO-OP), string sort keys from with
// expressions (previously truncated to 32 bits, so long keys with a
// common prefix like get_full_name() paths mis-sorted silently), real
// keys, and per-call iterator binding.
class g10_comp;
  string nm;
  int id;
  real w;
  function new(string s, int i, real r); nm = s; id = i; w = r; endfunction
  function string get_full_name(); return nm; endfunction
endclass

class g10_env;
  g10_comp cq[$];
  int iq[$];
  function void isort(); iq.sort(); endfunction
endclass

module g10_ordering_methods_test;
  int errors = 0;
  int q[$];
  string sq[$];
  byte d[];
  g10_env e;
  g10_comp t;

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask
  task scheck(string what, string got, string exp);
    if (got != exp) begin
      $display("FAIL %s: got %s expect %s", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    // LRM 7.12.2 examples: plain sort ascending, queue of int
    q.push_back(4); q.push_back(5); q.push_back(3); q.push_back(1);
    q.sort;
    check("q.sort[0]", q[0], 1); check("q.sort[3]", q[3], 5);
    q.rsort();
    check("q.rsort[0]", q[0], 5); check("q.rsort[3]", q[3], 1);
    q.reverse();
    check("q.reverse[0]", q[0], 1); check("q.reverse[3]", q[3], 5);
    q.shuffle();
    check("q.shuffle size", q.size(), 4);
    check("q.shuffle sum", q.sum(), 13);

    // LRM string example: s.reverse / sort on string elements
    sq.push_back("world"); sq.push_back("sad"); sq.push_back("hello");
    sq.sort;
    scheck("sq.sort[0]", sq[0], "hello");
    scheck("sq.sort[2]", sq[2], "world");
    sq.reverse();
    scheck("sq.reverse[0]", sq[0], "world");

    // dynamic array receiver
    d = new[3]; d[0] = 9; d[1] = 2; d[2] = 5;
    d.sort;
    check("d.sort[0]", d[0], 2); check("d.sort[2]", d[2], 9);

    // class-property receivers (previously silently unsorted)
    e = new;
    e.iq.push_back(3); e.iq.push_back(1); e.iq.push_back(2);
    e.isort();
    check("prop sort internal", e.iq[0], 1);
    e.iq.push_back(0);
    e.iq.sort();
    check("prop sort external", e.iq[0], 0);
    e.iq.rsort();
    check("prop rsort", e.iq[0], 3);
    e.iq.reverse();
    check("prop reverse", e.iq[0], 0);
    e.iq.shuffle();
    check("prop shuffle sum", e.iq.sum(), 6);

    // string keys longer than 32 bits with a common prefix (the
    // get_full_name() shape) — previously mis-sorted silently
    t = new("uvm_test_top.env.zebra", 3, 0.5); e.cq.push_back(t);
    t = new("uvm_test_top.env.alpha", 1, 2.5); e.cq.push_back(t);
    t = new("uvm_test_top.env.mike",  2, 1.5); e.cq.push_back(t);
    e.cq.sort() with (item.get_full_name());
    check("strkey sort", e.cq[0].id, 1);
    check("strkey sort last", e.cq[2].id, 3);
    e.cq.rsort() with (item.nm);
    check("strkey rsort", e.cq[0].id, 3);

    // real keys
    e.cq.sort() with (item.w);
    check("realkey sort", e.cq[0].id, 3);   // w=0.5
    check("realkey sort last", e.cq[2].id, 1); // w=2.5

    // int key on object elements, paren-less with form
    e.cq.rsort with (item.id);
    check("intkey rsort", e.cq[0].id, 3);

    // iterator net must not be poisoned across element types in one
    // scope (class elements above, byte elements here)
    begin
      byte bq[$];
      bq.push_back(9); bq.push_back(2);
      bq.sort() with (item);
      check("byte after class iter", bq[0], 2);
    end

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
