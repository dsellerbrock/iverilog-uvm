// A pure combinational process may make and then restore an intermediate
// value while computing its final result.  Two such processes at an already
// stable fixed point must quiesce: waking the peer for the restored value
// makes this pair oscillate forever in zero time.
module sv_always_comb_fixed_point;
  logic a = 1'b0;
  logic b = 1'b0;

  always_comb begin
    a = ~b;
    a = b;
  end

  always_comb begin
    b = ~a;
    b = a;
  end

  initial begin
    #1;
    if (a !== 1'b0 || b !== 1'b0)
      $display("FAILED: a=%b b=%b", a, b);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
