// G09 remaining tail (M4): chained element stores through PLAIN
// dynamic-array outers and through class-PROPERTY outers.
//
//   c.dd[i][j] = v;   dd[i][j] = v; (in a method)   dd_sig[i][j] = v;
//
// were all SILENT NO-OPS: the $ivl_assoc$store2 rewrite fired only
// for queue-typed SIGNAL outers, and the %store/qo/i receiver
// machinery accepted only vvp_queue objects. The rewrite now covers
// any darray/queue outer — signal, explicit property (c.dd), and
// implicit-this property — and the store ops accept any vvp_darray
// receiver (fixed-size darrays keep out-of-range warn-and-skip
// semantics; queues keep append-at-size).
//
// Reads-back go through whole-row copies (known-good path) so this
// test pins the STORE side only.

class box;
  int dd[][];
  int q2[$][$];
  int aq[string][$];

  function void init();
    int tmp[$];
    dd = new[2];
    dd[0] = new[2];
    dd[1] = new[2];
    // NOTE: q2[0].push_back(x) — a METHOD on an indexed property
    // element — is the separate G70 tail, and `q2.push_back({})`
    // pushes a nil handle rather than an empty queue (separate
    // recorded gap), so the inner queue is seeded populated.
    tmp.push_back(100);
    tmp.push_back(101);
    q2.push_back(tmp);
  endfunction

  function void fill_this();
    dd[0][1] = 42;      // implicit-this darray-of-darray store
    aq["k"][0] = 9;     // implicit-this assoc-of-queue store
    q2[0][1] = 55;      // implicit-this queue-of-queue overwrite
    q2[0][2] = 56;      // implicit-this queue-of-queue append-at-size
  endfunction
endclass

module g09_darray_store2_test;
  box c;
  int row[];
  int qrow[$];
  int dd_sig[][];
  int errors = 0;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    c = new;
    c.init();
    c.fill_this();

    row = c.dd[0];
    check(row[1] == 42, "implicit-this darray-of-darray element store");
    check(row[0] == 0, "neighbor element preserved");

    qrow = c.aq["k"];
    check(qrow[0] == 9, "implicit-this assoc-of-queue element store");

    qrow = c.q2[0];
    check(qrow[1] == 55 && qrow[0] == 100,
          "implicit-this queue-of-queue element store");
    check(qrow.size() == 3 && qrow[2] == 56,
          "queue-of-queue append-at-size store");

    // external-receiver property store
    c.dd[1][0] = 7;
    row = c.dd[1];
    check(row[0] == 7, "external-receiver darray-of-darray element store");

    // plain darray-of-darray SIGNAL outer
    dd_sig = new[2];
    dd_sig[0] = new[3];
    dd_sig[0][2] = 11;
    row = dd_sig[0];
    check(row[2] == 11, "darray-of-darray signal element store");
    check(row[0] == 0, "signal store neighbor preserved");

    if (errors == 0)
      $display("PASSED: all g09 darray store2 checks");
    else
      $display("FAILED: %0d g09 store2 checks", errors);
    $finish(0);
  end
endmodule
