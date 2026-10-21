// IEEE 1800-2017/2023 §15.4.5/§15.4.9: a typeless-mailbox get with a
// non-equivalent ref type shall generate a run-time error.
module p15_04_mailbox_get_mismatch;
  mailbox messages;
  int value;

  initial begin
    messages = new();
    messages.put("string message");
    messages.get(value);
    $display("GET_MISMATCH_RETURNED value=%0d num=%0d", value, messages.num());
    $finish;
  end
endmodule
