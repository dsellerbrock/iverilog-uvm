// IEEE 1800-2017 7.10.1: `$' is the last queue index and remains an
// expression endpoint when followed by arithmetic in a queue slice.
module top;
  class queue_box;
    int values[$];
  endclass

  int q[$];
  int r[$];
  int last;
  int offset;
  int receiver_calls;
  queue_box box;
  queue_box boxes[$];

  function automatic int receiver_index();
    receiver_calls++;
    return 0;
  endfunction

  initial begin
    q = {2, 3, 4};
    last = q[$];
    q = q[0:$-1];
    if (last != 4 || q.size() != 2 || q[0] != 2 || q[1] != 3)
      $fatal(1, "exact corpus form failed: last=%0d q=%p", last, q);

    q = {10, 11, 12, 13, 14};
    offset = 2;
    r = q[1:$-offset];
    if (r.size() != 2 || r[0] != 11 || r[1] != 12)
      $fatal(1, "variable offset slice failed: r=%p", r);

    // Both `$' forms must derive the final index from the SAME receiver
    // evaluation. The old size()-based lowering cloned the indexed
    // class-property receiver and called receiver_index() twice (once for
    // the slice value and once for its size).
    box = new;
    box.values = {1, 2, 3};
    boxes = {box};
    receiver_calls = 0;
    r = boxes[receiver_index()].values[0:$-1];
    if (receiver_calls != 1 || r.size() != 2 || r[0] != 1 || r[1] != 2)
      $fatal(1, "offset receiver evaluated more than once: calls=%0d r=%p",
             receiver_calls, r);

    receiver_calls = 0;
    r = boxes[receiver_index()].values[1:$];
    if (receiver_calls != 1 || r.size() != 2 || r[0] != 2 || r[1] != 3)
      $fatal(1, "last receiver evaluated more than once: calls=%0d r=%p",
             receiver_calls, r);

    $display("PASSED");
  end
endmodule
