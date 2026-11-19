module issue3808_uarray_slice;
  typedef int pair_t[1:0];
  typedef int queue_t[$];
  int b[0:3], descending[4:1];
  int calls, selector_calls, queue_calls;
  integer i;
  queue_t q;
  int da[];
  pair_t from_assoc[int];

  class item;
    int marker;
  endclass
  typedef item handles_t[1:0];
  item x, y, handles[0:3];

  function automatic pair_t f(int offset);
    calls++;
    f[1] = 30 + offset;
    f[0] = 40 + offset;
  endfunction

  function automatic integer base(integer value);
    selector_calls++;
    return value;
  endfunction

  function automatic queue_t value();
    queue_calls++;
    return q;
  endfunction

  function automatic handles_t handle_pair();
    handle_pair[1] = x;
    handle_pair[0] = y;
  endfunction

  task automatic store_handles(int first);
    handles[first+:2] = handle_pair();
    if (handles[0] != null || handles[1] != x ||
        handles[2] != y || handles[3] != null)
      $fatal(1, "function result of class handles in an automatic task");
  endtask

  initial begin
    b[0] = 10;
    b[3] = 20;
    i = 1;
    b[base(i)+:2] = f(0);
    if (calls != 1 || selector_calls != 1 ||
        b[0] !== 10 || b[1] !== 30 || b[2] !== 40 || b[3] !== 20)
      $fatal(1, "blocking function slice");

    b[1:2] = f(1);
    if (calls != 2 || b[0] !== 10 || b[1] !== 31 || b[2] !== 41 || b[3] !== 20)
      $fatal(1, "constant function slice");

    b[base(i)+:2] <= f(2);
    i = 3;
    descending[i-:2] = f(3);
    if (calls != 4 || selector_calls != 2 || b[1] !== 31 || b[2] !== 41 ||
        descending[3] !== 33 || descending[2] !== 43)
      $fatal(1, "function before NBA update");
    #1;
    if (b[0] !== 10 || b[1] !== 32 || b[2] !== 42 || b[3] !== 20)
      $fatal(1, "function NBA snapshot");

    i = 'x;
    b[i+:2] = f(4);
    i = 9;
    b[i+:2] <= f(5);
    #1;
    if (calls != 6 || b[0] !== 10 || b[1] !== 32 || b[2] !== 42 || b[3] !== 20)
      $fatal(1, "invalid selector must still call the function without writing");

    i = -1;
    b[i+:2] = f(6);
    if (calls != 7 || b[0] !== 46 || b[1] !== 32 || b[2] !== 42 || b[3] !== 20)
      $fatal(1, "partially out-of-bounds function slice");

    // Exercise two executions of the same assignment. The second RHS
    // has the wrong size and must not copy the old temporary to b[0:1].
    for (int n = 0; n < 2; n++) begin
      if (n == 0) q = {50, 60};
      else q = {99};
      i = 1 - n;
      b[i+:2] = value();
    end
    if (queue_calls != 2 || b[0] !== 46 ||
        b[1] !== 50 || b[2] !== 60 || b[3] !== 20)
      $fatal(1, "queue function slice size check");

    da = new[2];
    da[0] = 70;
    da[1] = 80;
    descending[3:2] = da;
    if (descending[3] !== 70 || descending[2] !== 80)
      $fatal(1, "dynamic array into descending constant slice");

    for (int n = 0; n < 2; n++) begin
      if (n != 0) da = new[3];
      i = 1 - n;
      b[i+:2] <= da;
    end
    if (b[1] !== 50 || b[2] !== 60)
      $fatal(1, "dynamic array changed target before NBA");
    #1;
    if (b[0] !== 46 || b[1] !== 70 || b[2] !== 80 || b[3] !== 20)
      $fatal(1, "dynamic array NBA snapshot and size check");

    from_assoc[0] = '{90, 100};
    b[i+:2] = from_assoc[0];
    if (b[0] !== 90 || b[1] !== 100 || b[2] !== 80 || b[3] !== 20)
      $fatal(1, "fixed array value from an associative element");

    x = new;
    y = new;
    store_handles(1);

    $display("PASSED");
  end
endmodule
