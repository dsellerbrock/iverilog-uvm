module p06_17a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  event done;  event done_too = done;  event empty = null;  event e1, e2;  int hits = 0;
  initial begin
    ck("alias_eq", done == done_too && done != e1);
    ck("null_cmp", empty == null && done != null);
    fork begin @(done_too); hits++; end begin #1; -> done; end join
    ck("alias_trigger", hits == 1);
    e2 = e1;
    fork begin @(e2); hits++; end begin #1; -> e1; end join
    ck("assign_share", hits == 2 && e2 == e1);
    e2 = null;  ck("assign_null_breaks", e2 == null && e1 != null);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
