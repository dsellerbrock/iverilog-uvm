// G09: nested dynamic containers (IEEE 1800-2017 7.4.5/20.7 dimension
// composition, 7.8/7.9 element access, 12.7.3 multi-variable foreach).
// Pins three fixes:
//  (1) mixed unpacked dimension lists compose right-to-left —
//      `int aq[int][$]` is an ASSOCIATIVE ARRAY OF QUEUES (previously
//      inverted into a plain queue of assoc arrays, so every keyed
//      operation silently misbehaved);
//  (2) chained element mutation: aq[k].push_back(v) auto-vivifies the
//      inner queue; aa[k1][k2] = v stores through the inner assoc
//      (previously the inner key and value were silently dropped —
//      the shape UVM report_server/printer/recorder depend on);
//  (3) multi-variable foreach over assoc-of-queue and queue-of-queue;
//  (4) inner ASSOCIATIVE foreach dimensions (first/next key descent,
//      12.7.3) — foreach (aa[k1, k2]) and foreach (qa[i, k]);
//  (5) chained keyed reads where the OUTER dimension is positional
//      (queue-of-assoc: qa[i][k]);
//  (6) 7.6/7.9.9 value semantics: storing an array into a container
//      element copies it — later mutation of the source must not
//      reach the stored element.
module g09_nested_container_test;
  int errors = 0;
  int qq[$][$];
  int t[$];
  int aq[int][$];
  int aa[int][string];
  string ss[string][string];
  int qa[$][string];
  int ta[string];
  int asi[string][int];
  string qs[$][string];
  string sa[string];
  int q1[$];
  int total;
  string keys;

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    // queue-of-queue: 2D foreach
    t.push_back(1); t.push_back(2); qq.push_back(t);
    t.delete(); t.push_back(3); qq.push_back(t);
    total = 0;
    foreach (qq[i, j]) total += qq[i][j];
    check("qq 2D foreach", total, 6);

    // assoc-of-queue (uvm_resource_pool::sort_by_precedence shape):
    // chained push auto-vivifies the inner queue
    aq[5].push_back(10);
    aq[5].push_back(11);
    aq[7].push_back(12);
    check("aq outer num", aq.num(), 2);
    check("aq elem read [5][1]", aq[5][1], 11);
    check("aq elem read [7][0]", aq[7][0], 12);
    total = 0;
    foreach (aq[k]) total++;
    check("aq 1D foreach", total, 2);
    total = 0;
    foreach (aq[k, i]) total += aq[k][i];
    check("aq 2D foreach", total, 33);

    // push_front ordering through the chained receiver (the exact
    // UVM sort_by_precedence idiom)
    aq[5].push_front(9);
    check("aq push_front", aq[5][0], 9);

    // assoc-of-assoc: chained stores and reads (uvm report_server
    // m_streams / printer m_recur_states shape)
    aa[1]["x"] = 100;
    aa[1]["y"] = 1;
    aa[3]["z"] = 10;
    check("aa outer num", aa.num(), 2);
    check("aa read [1][x]", aa[1]["x"], 100);
    check("aa read [1][y]", aa[1]["y"], 1);
    check("aa read [3][z]", aa[3]["z"], 10);
    total = aa[1]["x"] + aa[1]["y"] + aa[3]["z"];
    check("aa chained sum", total, 111);

    // string-valued nested assoc (m_streams is string-keyed both
    // levels with object values; use string values here)
    ss["ro"]["rh"] = "stream1";
    if (ss["ro"]["rh"] != "stream1") begin
      $display("FAIL ss chained store/read: got %s", ss["ro"]["rh"]);
      errors++;
    end

    // overwrite through the chain must not duplicate
    aa[1]["x"] = 200;
    check("aa overwrite", aa[1]["x"], 200);
    check("aa outer num stable", aa.num(), 2);

    // inner associative foreach dimension (12.7.3): assoc-of-assoc
    // (previously an explicit sorry — now first/next key descent)
    total = 0;
    foreach (aa[k1, k2]) total += aa[k1][k2];
    check("aa 2D foreach", total, 211);

    // string-keyed outer with int-keyed inner
    asi["x"][1] = 10; asi["x"][2] = 20; asi["y"][9] = 5;
    total = 0;
    foreach (asi[s, n]) total += asi[s][n];
    check("asi 2D foreach", total, 35);

    // queue-of-assoc: the OUTER dimension is positional, the inner is
    // keyed — chained reads must key the INNER element, not treat the
    // key as a queue position
    ta["a"] = 1; ta["b"] = 2;
    qa.push_back(ta);
    check("qa size", qa.size(), 1);
    check("qa read [0][a]", qa[0]["a"], 1);
    check("qa read [0][b]", qa[0]["b"], 2);
    ta.delete(); ta["c"] = 4;
    qa.push_back(ta);
    total = 0;
    foreach (qa[i, k]) total += qa[i][k];
    check("qa 2D foreach", total, 7);
    total = 0;
    foreach (qa[i]) total++;
    check("qa 1D foreach", total, 2);
    keys = "";
    foreach (qa[i, k]) if (i == 0) keys = {keys, k};
    if (keys != "ab") begin
      $display("FAIL qa inner key order: got %s expect ab", keys);
      errors++;
    end

    // string values through a positional-outer chain (eval_string path)
    sa["k"] = "v0";
    qs.push_back(sa);
    qs[0]["greet"] = "hello";
    if (qs[0]["greet"] != "hello") begin
      $display("FAIL qs chained store: got %s", qs[0]["greet"]);
      errors++;
    end
    if (qs[0]["k"] != "v0") begin
      $display("FAIL qs row preserved: got %s", qs[0]["k"]);
      errors++;
    end

    // chained stores for the remaining outer/inner shape combinations
    // (previously: keyed-outer/positional-inner was a silent no-op;
    // positional-outer stores clobbered the whole row)
    aq[5][1] = 42;                  // keyed outer, positional inner
    check("aq chained store", aq[5][1], 42);
    check("aq neighbors kept", aq[5][0], 9);
    qq[0][0] = 60;                  // positional outer, positional inner
    check("qq chained store", qq[0][0], 60);
    check("qq neighbors kept", qq[0][1], 2);

    // 7.6/7.9.9 value semantics: element stores copy array values
    ta.delete(); ta["a"] = 1;
    qa.delete();
    qa.push_back(ta);
    ta["a"] = 99;
    check("push_back copies (7.6)", qa[0]["a"], 1);
    q1.push_back(5);
    aq.delete();
    aq[3] = q1;
    q1.push_back(6);
    check("keyed store copies (7.9.9)", aq[3][0], 5);
    check("source queue unaffected", q1.size(), 2);
    total = 0;
    foreach (aq[k, i]) total++;
    check("stored queue kept 1 elem", total, 1);

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
