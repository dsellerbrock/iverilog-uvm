// M4 close-out: the five recorded residual container gaps.
//
// G70: class-method calls on PLAIN-DARRAY elements (succ[iter]
//      .get_parent(), the uvm_phase successor-walk shape) errored
//      "not a dynamic array method" — the element-select routing
//      accepted only queues.
// $size family: $size/$high/$low/$left/$right/$increment/
//      $unpacked_dimensions on dynamic-container PROPERTY receivers
//      constant-folded to 'x' (get_array_info had no property case);
//      now rewritten to the size sfunc (darrays are 0-based, 20.7).
// Display reads: $display("%0d", c.dd[0][1]) drew the chained select
//      in OBJECT context (the vpi arg classifier fell back to the
//      class-typed ROOT signal when the select carried no net type)
//      and printed null.
// G40: unique()/unique_index() on fixed-size unpacked arrays
//      returned empty (7.12.1 applies to any unpacked array).
// G73: the empty queue literal {} produced a NULL handle, so
//      q_of_q.push_back({}) stored nil and element stores through
//      the inner handle silently skipped (7.10.4: {} is an empty
//      queue value).

class m4_comp;
  m4_comp parent;
  function m4_comp get_parent();
    return parent;
  endfunction
endclass

class m4_box;
  int da[];
  int q[$];
  int dd[][];
  int q2[$][$];
endclass

module m4_closeout_test;
  m4_comp root;
  m4_comp succ[];
  m4_box b;
  int u[6];
  int r[$];
  int ri[$];
  int qrow[$];
  int row[];
  int n;
  int errors = 0;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    // G70: darray-of-class element method calls (incl. foreach index)
    root = new;
    succ = new[2];
    succ[0] = new; succ[0].parent = root;
    succ[1] = new; succ[1].parent = null;
    n = 0;
    foreach (succ[iter]) begin
      if (succ[iter].get_parent() != root)
        n++;
    end
    check(n == 1, "G70 darray-element method in foreach");
    check(succ[0].get_parent() == root, "G70 direct indexed call");

    // $size family on property receivers
    b = new;
    b.da = new[4];
    b.q.push_back(1); b.q.push_back(2);
    check($size(b.da) == 4 && $high(b.da) == 3 && $low(b.da) == 0,
          "$size/$high/$low on darray property");
    check($increment(b.da) == -1 && $unpacked_dimensions(b.da) == 1,
          "$increment/$unpacked_dimensions on darray property");
    check($size(b.q) == 2 && $high(b.q) == 1,
          "$size/$high on queue property");

    // display-context chained property reads (pinned via comparison
    // in a $sformatf, the same drawing path as $display args)
    b.dd = new[1];
    row = new[2]; row[1] = 42;
    b.dd[0] = row;
    check($sformatf("%0d", b.dd[0][1]) == "42",
          "display-context chained property read");

    // G40: unique / unique_index on a fixed-size unpacked array
    u = '{3,1,3,2,1,3};
    r = u.unique();
    ri = u.unique_index();
    check(r.size() == 3 && r[0] == 3 && r[1] == 1 && r[2] == 2,
          "G40 unique on unpacked array");
    check(ri.size() == 3 && ri[0] == 0 && ri[1] == 1 && ri[2] == 3,
          "G40 unique_index on unpacked array");

    // G73: {} is an empty queue, not nil
    b.q2.push_back({});
    check(b.q2[0].size() == 0, "G73 pushed inner is an empty queue");
    b.q2[0][0] = 100;    // append-at-size through the inner queue
    b.q2[0][1] = 101;
    qrow = b.q2[0];
    check(qrow.size() == 2 && qrow[0] == 100 && qrow[1] == 101,
          "G73 element stores through pushed empty queue");
    // clearing assignment still works
    r = {};
    check(r.size() == 0, "q = {} clears");

    if (errors == 0)
      $display("PASSED: all m4 close-out checks");
    else
      $display("FAILED: %0d m4 close-out checks", errors);
    $finish(0);
  end
endmodule
