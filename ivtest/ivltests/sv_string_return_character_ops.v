module sv_string_return_character_ops;
  int rhs_calls;
  function automatic string nested_string();
    nested_string = "X";
    nested_string[0] += 1;
  endfunction
  function automatic int nested_rhs();
    string got;
    rhs_calls++;
    got = nested_string();
    if (got != "Y") $fatal(1, "nested RHS return slot");
    return 1;
  endfunction
  function automatic string arithmetic();
    arithmetic = "\310\201\177";
    arithmetic[0] /= 2;
    arithmetic[1] %= 8'h7f;
    arithmetic[2] += 16'h0101;
    arithmetic[2] *= 2;
    arithmetic[0] >>>= 2;
    arithmetic[1] >>= 1;
    arithmetic[1] |= 8'h80;
    arithmetic[2] ^= 8'hff;
    arithmetic[2] &= 8'h7f;
    arithmetic[2] -= nested_rhs();
  endfunction
  function automatic string recurse(input int depth);
    string inner;
    recurse = "A";
    if (depth) begin
      recurse[0] += 1;
      inner = recurse(depth-1);
      if (recurse != "B")
        $fatal(1, "outer return frame changed across recursion: %s", recurse);
      recurse = {inner, "A"};
    end
    recurse[0] += 1;
  endfunction
  initial begin
    if (arithmetic() != "\371\201\176" || rhs_calls != 1)
      $fatal(1, "return arithmetic or RHS isolation");
    begin
      string recursive;
      recursive = recurse(2);
      if (recursive != "DAA")
        $fatal(1, "recursive return-frame isolation: %s", recursive);
    end
    $display("PASSED");
  end
endmodule
