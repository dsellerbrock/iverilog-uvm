// R25 addressed ref-binding: adversarial siblings.
class obj_c;
  int p = 0;
endclass

module top;
  int q[$];
  int da[];
  int arr[8];
  obj_c o1, o2, oref;
  int fails = 0;

  task automatic w_delay(ref int x, input int val, input int del);
    fork begin #(del) x = val; end join_none
  endtask

  task automatic w_wait(ref int x, input int val);
    // Task WAITS for its child: classic in-call write.
    x = val;
    #1;
  endtask

  task automatic w_killed(ref int x, input int val);
    fork begin #50 x = val; end join_none
  endtask

  task automatic w_recurse(ref int x, input int depth);
    if (depth > 0) w_recurse(x, depth - 1);
    else fork #2 x = 77; join_none
  endtask

  initial begin
    q.push_back(0); q.push_back(0);
    da = new[4];
    o1 = new; o2 = new;

    // 1. Queue element bound, queue GROWS before the detached write:
    //    the binding is by index, so q[1] must get the value.
    w_delay(q[1], 11, 2);
    q.push_back(0);          // resize between bind and write
    // 2. Two concurrent calls, different elements of one array.
    w_delay(arr[3], 33, 1);
    w_delay(arr[5], 55, 1);
    // 3. Property binding survives the HANDLE VARIABLE being reassigned:
    //    the ref names o1's storage, not the variable oref.
    oref = o1;
    w_delay(oref.p, 99, 2);
    oref = o2;               // must NOT retarget the pending write
    // 4. In-call (waiting) write through addressed binding.
    w_wait(arr[7], 7);
    // 5. Variable index.
    begin
      automatic int i = 2;
      w_delay(da[i], 22, 1);
    end
    // 6. Recursion chain ends in a detached write.
    w_recurse(arr[0], 3);
    // 7. Killed child: write must NOT land.
    fork : killer
      w_killed(arr[6], 66);
    join_none
    #5 disable killer;

    #100;
    if (q[1] != 11)  begin fails++; $display("FAIL q[1]=%0d expect 11 (resize)", q[1]); end
    if (arr[3] != 33) begin fails++; $display("FAIL arr[3]=%0d", arr[3]); end
    if (arr[5] != 55) begin fails++; $display("FAIL arr[5]=%0d", arr[5]); end
    if (o1.p != 99)  begin fails++; $display("FAIL o1.p=%0d expect 99", o1.p); end
    if (o2.p != 0)   begin fails++; $display("FAIL o2.p=%0d expect 0 (handle reassign)", o2.p); end
    if (arr[7] != 7) begin fails++; $display("FAIL arr[7]=%0d", arr[7]); end
    if (da[2] != 22) begin fails++; $display("FAIL da[2]=%0d (var index)", da[2]); end
    if (arr[0] != 77) begin fails++; $display("FAIL arr[0]=%0d (recursion)", arr[0]); end
    if (fails == 0) $display("PASSED");
    else $display("FAIL count=%0d", fails);
  end
endmodule
