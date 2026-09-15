module sv_string_character_compound;
  string text = "ABC";
  string high;
  int calls;
  function automatic int index_once(); calls++; return 1; endfunction
  task automatic update_argument(ref string value, input int index);
    value[index] += 1;
  endtask
  initial begin : local_control
    string local_text;
    local_text = "xyz";
    text[index_once()] += 1;
    if (text != "ACC" || calls != 1) $fatal(1, "add text=%s calls=%0d", text, calls);
    text[1] -= 2;
    if (text != "AAC") $fatal(1, "subtract text=%s", text);
    text[0] <<= 1;
    if (text != "\202AC") $fatal(1, "shift text=%s", text);
    high = "\310\201\177";
    high[0] /= 2;
    high[1] %= 8'h7f;
    high[2] += 16'h0101;
    if (high != "\344\002\200") $fatal(1, "arithmetic bytes=%h", high);
    high[2] *= 2;
    high[0] >>>= 2;
    high[1] >>= 1;
    high[1] |= 8'h80;
    high[2] ^= 8'hff;
    if (high != "\371\201\177") $fatal(1, "bitwise bytes=%h", high);
    update_argument(local_text, 1);
    if (local_text != "xzz") $fatal(1, "local/ref argument text=%s", local_text);
    $display("PASSED");
  end
endmodule
