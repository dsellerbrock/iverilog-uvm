module test;
  int calls;

  function automatic int step(input int value);
    calls += 1;
    return value + 1;
  endfunction

  initial begin
    for (int i = 0; i < 200100; i += 1) begin
      if (step(i) != i + 1) begin
        $display("FAILED at call %0d", i);
        $finish(1);
      end
    end

    if (calls != 200100) begin
      $display("FAILED call count %0d", calls);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
