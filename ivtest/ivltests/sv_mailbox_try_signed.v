// IEEE 1800 15.4.6, 15.4.8: try_get/try_peek return a signed int, negative
// on a message type mismatch, so the call compares signed in place.
module sv_mailbox_try_signed;
  mailbox m = new;
  int sent = 123;
  byte wrong;
  int result;
  initial begin
    m.put(sent);
    result = m.try_peek(wrong);
    $display("peek result=%0d stored=%b direct=%b cast=%b", result,
             result < 0, m.try_peek(wrong) < 0, $signed(m.try_peek(wrong)) < 0);
    result = m.try_get(wrong);
    $display("get  result=%0d stored=%b direct=%b sum=%0d", result,
             result < 0, m.try_get(wrong) < 0, m.try_get(wrong) + 0);
    $display("num=%0d", m.num());
  end
endmodule
