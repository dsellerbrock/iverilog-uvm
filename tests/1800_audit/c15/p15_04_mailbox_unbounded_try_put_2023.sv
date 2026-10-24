// IEEE 1800-2023 §15.4.4: an unbounded mailbox is never full, so try_put succeeds.
module p15_04_mailbox_unbounded_try_put_2023;
  mailbox #(int) messages;
  int result;

  initial begin
    messages = new();
    result = messages.try_put(17);
    if (result <= 0 || messages.num() != 1)
      $fatal(1, "try_put on unbounded mailbox failed: result=%0d num=%0d",
             result, messages.num());
    $display("PASS 2023 unbounded try_put");
    $finish;
  end
endmodule
