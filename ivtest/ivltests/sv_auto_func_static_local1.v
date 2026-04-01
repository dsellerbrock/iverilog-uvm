module test;
  function automatic int next_id();
    static int c;
    c = c + 1;
    return c;
  endfunction

  initial begin
    if (next_id() !== 1) begin
      $display("FAILED: first automatic/static call mismatch");
      $finish(1);
    end

    if (next_id() !== 2) begin
      $display("FAILED: static local did not persist across calls");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
