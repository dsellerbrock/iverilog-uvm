// G09 tail: container method calls on INDEXED-ELEMENT receivers in
// expression and statement context (IEEE 1800-2017 7.12 array methods
// apply to any unpacked array expression; 7.9.1 num()/size(), 7.9.2
// delete(), 7.9.3 exists(), 7.9.4 traversal; 7.10.2 queue methods).
// Previously these were compile-progress stubs: size/num returned
// constant 0, sum/exists returned null, pop_back in assignment context
// was constant-folded to 0 by the class-typed test_width bailout, and
// keyed delete on an assoc element positionally deleted (silent no-op).
// Also pins the exists() return value: 1, not an all-ones vector
// (aa.exists(k) + 1 must be 2).
module g09_elem_methods_test;
  int errors = 0;
  int aq[int][$];
  int as[string][$];
  int qa[$][string];
  int aa[int][string];
  int ta[string];
  int idxs[$];
  int found[$];
  int mq[$];
  int r;
  string sk;
  class C;
    int v;
    function new(int x); v = x; endfunction
    function int getv(); return v; endfunction
  endclass
  C cq[$];
  C c0;

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    // query methods on queue elements of an assoc-of-queue
    aq[5].push_back(10); aq[5].push_back(11); aq[7].push_back(1);
    check("aq elem size", aq[5].size(), 2);
    check("aq elem sum", aq[5].sum(), 21);
    r = aq[5].size();
    check("aq elem size assign", r, 2);
    r = aq[5].sum() + 1;
    check("aq elem sum operand", r, 22);

    // assoc elements of a queue-of-assoc
    ta["a"] = 1; ta["b"] = 2; qa.push_back(ta);
    check("qa elem num", qa[0].num(), 2);
    check("qa elem size", qa[0].size(), 2);

    // exists on an assoc element, and the 7.9.3 return value shape
    aa[3]["z"] = 7;
    check("aa elem exists hit", aa[3].exists("z"), 1);
    check("aa elem exists miss", aa[3].exists("q"), 0);
    check("exists is 1 not all-ones", aa[3].exists("z") + 1, 2);

    // traversal on an assoc element
    aa[3]["a"] = 9;
    r = aa[3].first(sk);
    check("aa elem first ok", r, 1);
    if (sk != "a") begin
      $display("FAIL aa elem first key: got %s expect a", sk);
      errors++;
    end
    r = aa[3].next(sk);
    check("aa elem next ok", r, 1);
    if (sk != "z") begin
      $display("FAIL aa elem next key: got %s expect z", sk);
      errors++;
    end

    // pop through the element handle mutates the stored queue —
    // assignment context exercises the test_width path that used to
    // constant-fold to zero
    r = aq[5].pop_back();
    check("aq elem pop_back", r, 11);
    check("aq elem size after pop", aq[5].size(), 1);
    r = aq[5].pop_front();
    check("aq elem pop_front", r, 10);
    check("aq elem empty", aq[5].size(), 0);

    // locators and min/max on elements (queue-typed results)
    aq[5].push_back(11); aq[5].push_back(2); aq[5].push_back(9);
    idxs = aq[5].find_first_index(x) with (x == 2);
    check("elem find_first_index size", idxs.size(), 1);
    check("elem find_first_index val", idxs[0], 1);
    found = aq[5].find(x) with (x > 5);
    check("elem find count", found.size(), 2);
    mq = aq[5].max();
    check("elem max", mq[0], 11);
    mq = aq[5].min();
    check("elem min", mq[0], 2);

    // string-keyed outer dimension
    as["ro"].push_back(6); as["ro"].push_back(1);
    check("string-keyed elem size", as["ro"].size(), 2);
    check("string-keyed elem sum", as["ro"].sum(), 7);

    // statement-context methods on indexed receivers
    aq[5].sort();
    check("elem sort [0]", aq[5][0], 2);
    check("elem sort [2]", aq[5][2], 11);
    aq[5].delete(1);
    check("elem positional delete", aq[5].size(), 2);
    aq[5].delete();
    check("elem delete all", aq[5].size(), 0);

    // keyed delete on an assoc ELEMENT (7.9.2) — must erase the key,
    // not queue position; was a silent no-op
    qa[0].delete("a");
    check("elem keyed delete", qa[0].num(), 1);
    check("elem keyed delete kept b", qa[0]["b"], 2);

    // class elements are untouched by the container dispatch
    c0 = new(42); cq.push_back(c0);
    check("class elem property", cq[0].v, 42);
    check("class elem method", cq[0].getv(), 42);

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
