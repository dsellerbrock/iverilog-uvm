// G71: foreach over a class-property plain dynamic array silently
// iterated ZERO times (IEEE 1800-2017 12.7.3, 7.5).
//
// Root cause was two-layered:
//  1. elaboration lowered darray foreach bounds via $low/$high, and
//     get_array_info() constant-folded $high(<property>) to 'x' (no
//     NetEProperty case), so the loop condition was never true.
//     Dynamic arrays are always 0-based (7.5), so darray foreach now
//     uses the same 0 <= i < size loop as queues; the size sfunc
//     accepts property receivers.
//  2. once the loop ran, the nested descent (dd[i,j]) crashed:
//     eval_object_select routed plain-darray property selects down the
//     arrayed-property path (%prop/obj with the ELEMENT index as the
//     property-array index -> assertion). Darray property selects now
//     use the object-indexed load path, and %load/qo/* accepts any
//     vvp_darray receiver.
//
// Queue and associative property receivers were already correct; they
// are pinned here as characterization.

class box;
  int da[];
  int q[$];
  int aa[string];
  int dd[][];
  string sda[];

  function void fill();
    int row[];
    da = new[4];
    foreach (da[i]) da[i] = i * 3;      // this-receiver darray foreach
    q.push_back(4); q.push_back(5);
    aa["x"] = 6; aa["y"] = 7;
    // Rows populated by whole-row assignment: chained element stores
    // through a plain-darray outer (dd[i][j] = v) are a recorded
    // remaining tail (G09: darray outers in the store2 rewrite).
    dd = new[2];
    row = new[2]; row[0] = 1; row[1] = 2;
    dd[0] = row;
    row = new[3]; row[0] = 3; row[1] = 4; row[2] = 5;
    dd[1] = row;
    sda = new[2]; sda[0] = "ab"; sda[1] = "cd";
  endfunction

  function int count_da_this();
    int cnt = 0;
    foreach (da[i]) cnt++;
    return cnt;
  endfunction
endclass

module g71_foreach_prop_darray_test;
  box b;
  int errors = 0;
  int cnt, sum;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    b = new;
    b.fill();

    // this-receiver darray foreach inside a class method
    check(b.count_da_this() == 4, "this-receiver darray foreach count");

    // external-receiver darray foreach: iteration count
    cnt = 0;
    foreach (b.da[i]) cnt++;
    check(cnt == 4, "external darray foreach count");

    // element reads through the property receiver
    sum = 0;
    foreach (b.da[i]) sum += b.da[i];
    check(sum == 18, "external darray foreach element reads");

    // element writes through the property receiver
    foreach (b.da[i]) b.da[i] = 100 + i;
    check(b.da[0] == 100 && b.da[3] == 103,
          "external darray foreach element writes");

    // string-element darray property (reads + comparison; a method
    // call on the indexed element, b.sda[i].len(), is the separate
    // G70 indexed-element-method tail)
    cnt = 0;
    foreach (b.sda[i]) if (b.sda[i] == "ab" || b.sda[i] == "cd") cnt++;
    check(cnt == 2, "string-element darray property foreach");

    // nested two-index foreach over jagged darray-of-darray property
    cnt = 0; sum = 0;
    foreach (b.dd[i, j]) begin
      cnt++;
      sum += b.dd[i][j];
    end
    check(cnt == 5, "jagged darray-of-darray foreach count");
    check(sum == 15, "jagged darray-of-darray element reads");

    // characterization: queue + assoc property receivers stay correct
    cnt = 0;
    foreach (b.q[i]) cnt++;
    check(cnt == 2, "queue property foreach count");
    cnt = 0;
    foreach (b.aa[k]) cnt++;
    check(cnt == 2, "assoc property foreach count");

    if (errors == 0)
      $display("PASSED: all g71 foreach property-darray checks");
    else
      $display("FAILED: %0d g71 checks", errors);
    $finish(0);
  end
endmodule
