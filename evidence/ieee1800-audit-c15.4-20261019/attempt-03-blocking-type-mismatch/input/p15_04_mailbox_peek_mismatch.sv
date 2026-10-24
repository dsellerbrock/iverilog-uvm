// IEEE 1800-2017/2023 §15.4.7/§15.4.9: a typeless-mailbox peek with a
// non-equivalent ref type shall generate a run-time error.
module p15_04_mailbox_peek_mismatch;
  mailbox messages;
  int value;

  initial begin
    messages = new();
    messages.put("string message");
    messages.peek(value);
    $display("PEEK_MISMATCH_RETURNED value=%0d num=%0d", value, messages.num());
    $finish;
  end
endmodule
