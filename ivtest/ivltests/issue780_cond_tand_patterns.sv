// IEEE 1800-2017/2023 11.4.11 and 12.6.3
module issue780_cond_tand_patterns;
  typedef union tagged packed { void Invalid; logic [3:0] Valid; } word_t;
  word_t v;
  int n = 77;
  int value_out, calls = 0;
  logic y = 1;
  logic unknown_filter;
  logic [3:0] merged;
  string text;

  function automatic bit probe(input bit result);
    calls++;
    return result;
  endfunction

  function automatic bit replace_value();
    v = tagged Valid 4'd9;
    return 1;
  endfunction

  function automatic int extract(input logic [3:0] data);
    word_t local_value;
    local_value = tagged Valid data;
    return local_value matches tagged Valid .n &&& n matches .n ? n : -1;
  endfunction

  initial begin
    v = tagged Valid 4'd5;
    value_out = y &&& v matches tagged Valid .n &&& n > 3 ? n : -1;
    if (value_out !== 5)
      $fatal(1, "leading filter or consequent binding: %0d", value_out);

    value_out = v matches tagged Valid .n &&& n matches .value ? value : -1;
    if (value_out !== 5)
      $fatal(1, "second pattern binding: %0d", value_out);

    text = y &&& v matches tagged Valid .n &&& n matches .value
           ? $sformatf("%0d", value) : "failed";
    if (text != "5")
      $fatal(1, "typed conditional consequent: %s", text);

    value_out = y &&& v matches tagged Valid .n &&& replace_value() &&&
                n matches .value ? value : -1;
    if (value_out !== 5 || v.Valid !== 4'd9)
      $fatal(1, "capture precedes a side-effecting filter: %0d", value_out);

    if (extract(0) !== 0 || extract(8) !== 8)
      $fatal(1, "zero binding or shadowed subject in an automatic function");

    v = tagged Valid 4'd5;
    value_out = probe(0) &&& v matches tagged Valid .n &&& probe(1) ? n : n;
    if (value_out !== 77 || calls !== 1)
      $fatal(1, "failed filter short-circuit or alternative scope");

    v = tagged Invalid;
    value_out = y &&& v matches tagged Valid .n &&& probe(1) ? n : n;
    if (value_out !== 77 || calls !== 1)
      $fatal(1, "failed match short-circuit or alternative scope");

    v = tagged Valid 4'd5;
    unknown_filter = 1'bx;
    merged = v matches tagged Valid .n &&& unknown_filter &&&
             n matches .value ? value : 4'b0100;
    if (merged !== 4'b010x)
      $fatal(1, "ambiguous filter and consequent merge: %b", merged);

    value_out = probe(0) &&& v matches tagged Valid .n ? n :
                y &&& v matches tagged Valid .n &&& n matches .value
                  ? (value matches .inner ? inner : -1) : -2;
    if (value_out !== 5 || calls !== 2)
      $fatal(1, "nested, right-associative conditionals");

    value_out = y ? 0 :
                probe(1) &&& v matches tagged Valid .n ? n : -1;
    if (value_out !== 0 || calls !== 2)
      $fatal(1, "right-associative alternative was evaluated");

    $display("PASSED");
  end
endmodule
