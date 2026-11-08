module issue2734_queue_property_compound;
  class box;
    int values[$];
  endclass

  box boxes[$];
  box b;
  int calls;

  function automatic int ri();
    calls++;
    return 0;
  endfunction

  initial begin
    b = new;
    b.values = {1, 2, 3};
    boxes = {b};

    boxes[ri()].values[1] = 9;
    if (calls != 1 || b.values[1] != 9)
      $fatal(1, "simple assignment failed: calls=%0d values=%p", calls, b.values);
    $display("= : %p calls=%0d", b.values, calls);

    boxes[ri()].values[1] += 1;
    if (calls != 2 || b.values[1] != 10)
      $fatal(1, "compound assignment failed: calls=%0d values=%p", calls, b.values);
    $display("+=: %p calls=%0d", b.values, calls);

    boxes[0].values[1] += 1;
    if (b.values[1] != 11)
      $fatal(1, "constant-index compound assignment failed: %p", b.values);
    $display("constant +=: %p", b.values);
  end
endmodule
