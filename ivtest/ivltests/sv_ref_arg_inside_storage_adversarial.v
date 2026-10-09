// Ordinary ref with blocking joins plus static ref in detached processes.
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
    fork begin #(del) x = val; end join
  endtask

  task automatic w_wait(ref int x, input int val);
    // Task WAITS for its child: classic in-call write.
    x = val;
    #1;
  endtask

  task automatic w_killed(ref static int x, input int val);
    fork begin #50 x = val; end join_none
  endtask

  task automatic w_recurse(ref static int x, input int depth);
    if (depth > 0) w_recurse(x, depth - 1);
    else fork #2 x = 77; join_none
  endtask

  initial begin
    q.push_back(0); q.push_back(0);
    da = new[4];
    o1 = new; o2 = new;

    // Queue element remains bound while a sibling appends to the queue.
    fork
      w_delay(q[1], 11, 2);
      begin #1 q.push_back(0); end
    join
    // Concurrent ordinary-ref writes target distinct fixed-array elements.
    fork
      w_delay(arr[3], 33, 1);
      w_delay(arr[5], 55, 1);
    join
    // The pending write retains o1's property after the caller handle changes.
    oref = o1;
    fork
      w_delay(oref.p, 99, 2);
      begin #1 oref = o2; end
    join
    // In-call write through an ordinary ref.
    w_wait(arr[7], 7);
    // An automatic index can select a dynamic-array element for ordinary ref.
    begin
      automatic int i = 2;
      w_delay(da[i], 22, 1);
    end
    // A recursion chain ends in a detached write.
    w_recurse(arr[0], 3);
    // A killed child must not write through the static ref.
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
