module p06_24b;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  typedef enum {red, green, blue, yellow, white, black} Colors;
  Colors col;  int r, d;  byte by;  string s;  logic [3:0] lv;
  initial begin
    r = $cast(col, 2 + 3);         ck("fn_valid", r == 1 && col == black);
    col = red;
    r = $cast(col, 2 + 8);         ck("fn_invalid_unchanged", r == 0 && col == red);
    col = green;
    r = $cast(col, -1);            ck("fn_negative_invalid", r == 0 && col == green);
    $cast(col, 3);                 ck("task_valid", col == yellow);
    r = $cast(col, yellow);        ck("fn_same_type", r == 1 && col == yellow);
    r = $cast(d, 3.7);             ck("real_to_int", r == 1 && d == 4);
    r = $cast(s, "abc");           ck("string", r == 1 && s == "abc");
    r = $cast(by, 8'hFE);          ck("byte_value", r == 1 && by == -2);
    col = red; lv = 4'b01x0;
    r = $cast(col, lv);            ck("fn_xz_invalid_unchanged", r == 0 && col == red);
    col = Colors'(10);             ck("static_cast_no_check", int'(col) == 10);
    r = $cast(by, 300);            $display("INFO cast_int_to_byte r=%0d by=%0d", r, by);
    $display("INFO plain_real_assign_control rv=%f", 7.0 * 1);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
