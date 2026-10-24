// IEEE 1800-2017/2023 §15.4.6, §15.4.8, and §15.4.9: nonblocking receives
// from the typeless default mailbox report mismatched runtime types.
module p15_04_mailbox_dynamic_type;
  mailbox messages;
  int failures = 0;

  task automatic check(string label, bit condition);
    if (!condition) begin
      failures++;
      $display("FAILED: %s", label);
    end
  endtask

  initial begin
    int int_value;
    int result;
    string string_value;

    messages = new();
    messages.put("typed at runtime");
    result = messages.try_peek(int_value);
    $display("try_peek(int): result=%0d num=%0d", result, messages.num());
    check("try_peek reports a negative type mismatch", result < 0);
    check("mismatched try_peek leaves the message queued", messages.num() == 1);
    result = messages.try_get(int_value);
    $display("try_get(int): result=%0d num=%0d", result, messages.num());
    check("try_get reports a negative type mismatch", result < 0);
    check("mismatched try_get leaves the message queued", messages.num() == 1);
    result = messages.try_peek(string_value);
    $display("try_peek(string): result=%0d num=%0d value=%s", result,
             messages.num(), string_value);
    check("try_peek succeeds with equivalent type", result > 0
          && string_value == "typed at runtime" && messages.num() == 1);
    result = messages.try_get(string_value);
    $display("try_get(string): result=%0d num=%0d value=%s", result,
             messages.num(), string_value);
    check("try_get succeeds and removes the message", result > 0
          && string_value == "typed at runtime" && messages.num() == 0);

    if (failures != 0)
      $fatal(1, "%0d dynamic mailbox checks failed", failures);
    $display("PASS mailbox clause 15.4 dynamic type");
    $finish;
  end
endmodule
