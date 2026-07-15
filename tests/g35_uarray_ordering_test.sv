// G35/G36 (M4 tail): ordering methods on STATIC unpacked arrays
// (IEEE 1800-2017 7.12.2 applies to any unpacked array). Previously
// u.sort()/u.rsort()/u.reverse()/u.shuffle() on a fixed-size array
// fell to the unknown-task compile-progress warning and silently did
// nothing. Lowered now to the in-place %uarr/order runtime op.
//
// Also pins G72 (found while implementing this): sort/rsort/unique on
// vec4-backed containers ignored the declared element SIGNEDNESS —
// `int q[$]` with negative values sorted in unsigned word order on
// queues and dynamic arrays alike. The %qsort/%qsort/r/%qunique ops
// now carry the element signedness.

module g35_uarray_ordering_test;
  int u[5];
  int s[6];
  bit [7:0] ub[4];
  int q[$];
  int da[];
  int errors = 0;
  int sum;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    // reverse (G35)
    u = '{1,2,3,4,5};
    u.reverse();
    check(u[0]==5 && u[1]==4 && u[2]==3 && u[3]==2 && u[4]==1,
          "static reverse");

    // signed sort / rsort (G36 + G72)
    s = '{3,-1,4,-1,5,0};
    s.sort();
    check(s[0]==-1 && s[1]==-1 && s[2]==0 && s[3]==3 && s[4]==4 && s[5]==5,
          "static signed sort");
    s.rsort();
    check(s[0]==5 && s[1]==4 && s[2]==3 && s[3]==0 && s[4]==-1 && s[5]==-1,
          "static signed rsort");

    // unsigned sort
    ub = '{200, 5, 130, 1};
    ub.sort();
    check(ub[0]==1 && ub[1]==5 && ub[2]==130 && ub[3]==200,
          "static unsigned sort");

    // shuffle preserves content
    u = '{10,20,30,40,50};
    u.shuffle();
    sum = 0;
    foreach (u[i]) sum += u[i];
    check(sum == 150, "static shuffle content");

    // G72 on queues: signed element sort
    q.push_back(3); q.push_back(-1); q.push_back(0); q.push_back(-7);
    q.sort();
    check(q[0]==-7 && q[1]==-1 && q[2]==0 && q[3]==3, "queue signed sort");
    q.rsort();
    check(q[0]==3 && q[1]==0 && q[2]==-1 && q[3]==-7, "queue signed rsort");

    // G72 on dynamic arrays
    da = new[3];
    da[0] = 5; da[1] = -2; da[2] = 0;
    da.sort();
    check(da[0]==-2 && da[1]==0 && da[2]==5, "darray signed sort");

    if (errors == 0)
      $display("PASSED: all g35 uarray ordering checks");
    else
      $display("FAILED: %0d g35 checks", errors);
    $finish(0);
  end
endmodule
