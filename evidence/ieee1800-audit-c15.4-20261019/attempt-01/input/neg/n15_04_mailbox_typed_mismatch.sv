// IEEE 1800-2017/2023 §15.4.9: concrete mailbox types check actuals at compile time.
module n15_04_mailbox_typed_mismatch;
  mailbox #(int) messages;
  initial begin
    messages = new();
    messages.put("not an int");
  end
endmodule
