// M10-1/R7: element selection on an array of class handles must honour its
// index, for every index shape.
//
// The ROADMAP claimed `arr[i]' silently read element 0, from reading a
// hardcoded `%ix/load 3, 0, 0' in tgt-vvp's IVL_EX_ARRAY path. That was a
// misreading: an indexed element read is IVL_EX_SIGNAL, and that path
// (eval_object_signal) evaluates the word index properly. IVL_EX_ARRAY is
// the whole array with no index at all, so it is only reachable from illegal
// whole-array-where-a-handle-is-required code -- now a loud error, covered by
// tests/negative/object_array_to_handle and object_array_as_handle_arg.
//
// This test pins the behaviour that was already correct, so the claim cannot
// be re-invented and the path cannot silently regress. A parse-only check
// would pass while reading the wrong element, so every case compares the
// element's own id against the index used to reach it.
module main;

  class C;
    int id;
    function new(int i);
      id = i;
    endfunction
  endclass

  C arr[4];
  C q[$];
  C dyn[];
  C aa[string];

  int errors = 0;

  task automatic want(int got, int wanted, string what);
    if (got !== wanted) begin
      $display("FAILED -- %s: got %0d, expected %0d", what, got, wanted);
      errors++;
    end
  endtask

  initial begin
    C tmp;

    for (int i = 0; i < 4; i++) begin
      arr[i] = new(100 + i);
    end

    // Constant index.
    want(arr[0].id, 100, "arr[0] constant index");
    want(arr[2].id, 102, "arr[2] constant index");
    want(arr[3].id, 103, "arr[3] constant index");

    // Run-time variable index -- the case a hardcoded index-0 would break.
    for (int i = 0; i < 4; i++) begin
      want(arr[i].id, 100 + i, $sformatf("arr[i] variable index i=%0d", i));
    end

    // Computed index expression.
    for (int i = 0; i < 3; i++) begin
      want(arr[i + 1].id, 101 + i, $sformatf("arr[i+1] expression index i=%0d", i));
    end

    // Descending walk, so a stuck index cannot coincidentally agree.
    for (int i = 3; i >= 0; i--) begin
      want(arr[i].id, 100 + i, $sformatf("arr[i] descending i=%0d", i));
    end

    // Writing THROUGH an indexed element must reach that element only.
    arr[2].id = 902;
    want(arr[2].id, 902, "write through arr[2]");
    want(arr[0].id, 100, "arr[0] untouched by arr[2] write");
    want(arr[1].id, 101, "arr[1] untouched by arr[2] write");
    want(arr[3].id, 103, "arr[3] untouched by arr[2] write");

    // Queue of handles.
    for (int i = 0; i < 4; i++) begin
      tmp = new(200 + i);
      q.push_back(tmp);
    end
    for (int i = 0; i < 4; i++) begin
      want(q[i].id, 200 + i, $sformatf("q[i] index i=%0d", i));
    end

    // Dynamic array of handles.
    dyn = new[4];
    for (int i = 0; i < 4; i++) begin
      dyn[i] = new(300 + i);
    end
    for (int i = 0; i < 4; i++) begin
      want(dyn[i].id, 300 + i, $sformatf("dyn[i] index i=%0d", i));
    end

    // Associative array of handles, string-keyed.
    aa["a"] = new(401);
    aa["b"] = new(402);
    want(aa["a"].id, 401, "aa[\"a\"]");
    want(aa["b"].id, 402, "aa[\"b\"]");

    if (errors == 0) $display("PASSED");
    $finish(0);
  end

endmodule
