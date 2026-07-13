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
//  (3) multi-variable foreach over assoc-of-queue and queue-of-queue.
module g09_nested_container_test;
  int errors = 0;
  int qq[$][$];
  int t[$];
  int aq[int][$];
  int aa[int][string];
  string ss[string][string];
  int total;

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

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
