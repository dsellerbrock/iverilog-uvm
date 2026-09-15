module sv_string_character_incdec_bounds;
  string text = "A";
  string empty = "";
  string high_bytes = "\310\377";
  string one_byte = "\001";
  logic [127:0] mixed, high, all_x;
  byte result;
  int wide_result;
  int calls;
  function automatic logic [127:0] idx(input logic [127:0] value); calls++; return value; endfunction
  initial begin
    mixed='0; mixed[1:0]=2'b1x; high='0; high[100]=1; all_x='x;
    result = text[idx(mixed)]++;
    if (result != 0 || text != "A") $fatal(1,"mixed OOB");
    result = ++text[idx(high)];
    if (result != 66 || text != "B") $fatal(1,"high truncation");
    result = empty[idx(0)]++;
    if (result != 0 || empty != "") $fatal(1,"empty");
    result = text[idx(all_x)]--;
    if (result != 66 || text != "A" || calls != 4) $fatal(1,"X conversion/calls");
    wide_result = high_bytes[0]++;
    if (wide_result != -56 || high_bytes[0] != 8'hc9)
      $fatal(1,"signed postfix widening result=%0d byte=%h",wide_result,high_bytes[0]);
    wide_result = ++high_bytes[0];
    if (wide_result != -54 || high_bytes[0] != 8'hca)
      $fatal(1,"signed prefix widening result=%0d byte=%h",wide_result,high_bytes[0]);
    wide_result = ++high_bytes[1];
    if (wide_result != 0 || high_bytes[1] != 8'hff)
      $fatal(1,"wrapped zero byte must not replace ff");
    result = text[idx(-1)]++;
    if (result != 0 || text != "A") $fatal(1,"negative postfix");
    result = ++text[idx(-1)];
    if (result != 1 || text != "A") $fatal(1,"negative prefix");
    result = one_byte[0]--;
    if (result != 1 || one_byte != "\001") $fatal(1,"zero-byte putc suppression");
    result = ++empty[idx(0)];
    if (result != 1 || empty != "") $fatal(1,"empty prefix boundary");
    $display("PASSED");
  end
endmodule
