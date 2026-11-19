// IEEE 1800-2017/2023 12.6, 12.6.3 and 11.4.11.
module issue3894_match_subject;
  typedef union tagged { void Invalid; int Valid; } value_t;
  typedef union tagged packed { logic signed [5:0] Data; void None; } packed_t;
  typedef union tagged { string Text; void Empty; } text_t;
  typedef int pair_t [2];

  value_t v;
  packed_t packed_value;
  text_t text_value;
  pair_t pair_value;
  int calls = 0;
  int guards = 0;
  int result;
  int x = 99;
  bit select_match;
  logic [3:0] merged;
  logic [5:0] bits_result;
  string text_result;

  function automatic value_t f(input value_t a);
    calls++;
    return a;
  endfunction

  function automatic bit guard(input int value);
    guards++;
    return value == 7;
  endfunction

  function automatic logic ambiguous_guard();
    return 1'bx;
  endfunction

  function automatic int descend(input int depth);
    value_t local_value;
    local_value = tagged Valid depth;
    return f(local_value) matches tagged Valid .held &&&
           (depth == 1 || descend(depth - 1) == depth - 1) ? held : -1;
  endfunction

  function automatic packed_t f_packed(input packed_t a);
    calls++;
    return a;
  endfunction

  function automatic text_t f_text(input text_t a);
    calls++;
    return a;
  endfunction

  function automatic pair_t f_pair(input pair_t a);
    calls++;
    f_pair = a;
  endfunction

  initial begin
    v = tagged Valid 7;
    result = f(v) matches tagged Valid .x ? x : -1;
    if (result !== 7 || calls != 1)
      $fatal(1, "match value=%0d calls=%0d", result, calls);
    $display("%0d %0d", result, calls);

    v = tagged Invalid;
    calls = 0;
    result = f(v) matches tagged Valid .x &&& guard(x) ? x : x;
    if (result !== 99 || calls != 1 || guards != 0)
      $fatal(1, "tag miss value=%0d calls=%0d guards=%0d", result, calls, guards);

    calls = 0;
    result = f(v) matches .* ? 17 : -1;
    if (result !== 17 || calls != 1)
      $fatal(1, "wildcard value=%0d calls=%0d", result, calls);

    v = tagged Valid 7;
    calls = 0;
    select_match = 0;
    // The right-associative inner conditional is in the outer false arm.
    result = !select_match ? 50 : f(v) matches tagged Valid .x ? x : -1;
    if (result !== 50 || calls != 0)
      $fatal(1, "unselected match value=%0d calls=%0d", result, calls);

    if (f(v) matches tagged Valid .x ? x == 7 : 1'b0) begin
      if (calls != 1)
        $fatal(1, "match in if predicate calls=%0d", calls);
    end else
      $fatal(1, "conditional in if predicate failed");

    calls = 0;
    result = f(v) matches tagged Valid .x &&& guard(x) ? x : -1;
    if (result !== 7 || calls != 1 || guards != 1)
      $fatal(1, "guarded match value=%0d calls=%0d guards=%0d", result, calls, guards);

    calls = 0;
    result = f(v) matches .saved
             ? (saved matches tagged Valid .x ? x : -1) : -2;
    if (result !== 7 || calls != 1)
      $fatal(1, "bound union value=%0d calls=%0d", result, calls);

    calls = 0;
    merged = f(v) matches tagged Valid .x &&& ambiguous_guard() ? 4'(x) : 4'b0101;
    if (merged !== 4'b01x1 || calls != 1)
      $fatal(1, "ambiguous predicate value=%b calls=%0d", merged, calls);

    calls = 0;
    result = descend(3);
    if (result !== 3 || calls != 3)
      $fatal(1, "recursive binding value=%0d calls=%0d", result, calls);

    calls = 0;
    packed_value = tagged Data (-6'sd3);
    result = f_packed(packed_value) matches tagged Data .d ? d : -1;
    if (result !== -3 || calls != 1)
      $fatal(1, "packed signed binding value=%0d calls=%0d", result, calls);
    packed_value = tagged Data 6'b10xz01;
    bits_result = f_packed(packed_value) matches tagged Data .d ? d : 6'b0;
    if (bits_result !== 6'b10xz01 || calls != 2)
      $fatal(1, "packed four-state binding value=%b calls=%0d", bits_result, calls);

    calls = 0;
    text_value = tagged Text "captured";
    text_result = f_text(text_value) matches tagged Text .txt ? txt : "miss";
    if (text_result != "captured" || calls != 1)
      $fatal(1, "string binding value=%s calls=%0d", text_result, calls);

    result = x - 100 matches .delta ? delta : -2;
    if (result !== -1)
      $fatal(1, "arithmetic subject value=%0d", result);

    calls = 0;
    pair_value = '{10, 11};
    result = f_pair(pair_value) matches .pair_copy
             ? pair_copy[0] + pair_copy[1] : -1;
    if (result !== 21 || calls != 1)
      $fatal(1, "array subject binding value=%0d calls=%0d", result, calls);
  end
endmodule
