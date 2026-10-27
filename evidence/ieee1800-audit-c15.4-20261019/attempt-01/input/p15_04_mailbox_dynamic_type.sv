// IEEE 1800-2017/2023 §15.4.5–§15.4.9: default mailbox is typeless and
// nonblocking receives report a run-time type mismatch without removing data.
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
    check("try_peek reports a negative type mismatch", result < 0);
    check("mismatched try_peek leaves the message queued", messages.num() == 1);
    result = messages.try_get(int_value);
    check("try_get reports a negative type mismatch", result < 0);
    check("mismatched try_get leaves the message queued", messages.num() == 1);
    result = messages.try_peek(string_value);
    check("try_peek succeeds with equivalent type", result > 0
          && string_value == "typed at runtime" && messages.num() == 1);
    result = messages.try_get(string_value);
    check("try_get succeeds and removes the message", result > 0
          && string_value == "typed at runtime" && messages.num() == 0);

    if (failures != 0)
      $fatal(1, "%0d dynamic mailbox checks failed", failures);
    $display("PASS mailbox clause 15.4 dynamic type");
    $finish;
  end
endmodule
