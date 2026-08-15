module t;
  int calls = 0;
  int final_value = 7;

  function int next_value();
    calls += 1;
    return calls;
  endfunction

  initial begin
    cover #0 (1) $display("COVER0 VALUE=%0d", next_value());
    cover #0 (0) $display("BAD_FALSE VALUE=%0d", next_value());

    $assertoff;
    cover #0 (1) $display("BAD_DISABLED VALUE=%0d", next_value());
    $asserton;

    for (int idx = 0; idx < 2; idx += 1)
      cover final (idx == 0)
        $display("BAD_CANCELLED VALUE=%0d", next_value());

    cover final (1) $display("COVER_FINAL VALUE=%0d", final_value);
    final_value = 99;
    $display("SOURCE CALLS=%0d VALUE=%0d", calls, final_value);
  end
endmodule
