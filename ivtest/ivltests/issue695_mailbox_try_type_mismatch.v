// IEEE 1800-2017/2023 15.4.6 and 15.4.8: a mailbox try operation returns
// a negative integer on a message type mismatch and leaves the message queued.
module issue695_mailbox_try_type_mismatch;
  mailbox mbx;
  string queued;
  string string_value;
  int int_value;
  int status;

  initial begin
    mbx = new;
    queued = "queued";
    int_value = 'h12345678;

    if (!mbx.try_put(queued))
      $fatal(1, "try_put failed");

    status = mbx.try_peek(int_value);
    if (status >= 0 || int_value !== 'h12345678 || mbx.num() != 1)
      $fatal(1, "try_peek mismatch status=%0d value=%h count=%0d",
             status, int_value, mbx.num());

    status = mbx.try_get(int_value);
    if (status >= 0 || int_value !== 'h12345678 || mbx.num() != 1)
      $fatal(1, "try_get mismatch status=%0d value=%h count=%0d",
             status, int_value, mbx.num());

    mbx.try_peek(int_value);
    if (int_value !== 'h12345678 || mbx.num() != 1)
      $fatal(1, "statement try_peek changed output or queue");

    mbx.try_get(int_value);
    if (int_value !== 'h12345678 || mbx.num() != 1)
      $fatal(1, "statement try_get changed output or queue");

    status = mbx.try_peek(string_value);
    if (status <= 0 || string_value != "queued" || mbx.num() != 1)
      $fatal(1, "matching try_peek status=%0d value=%s count=%0d",
             status, string_value, mbx.num());

    status = mbx.try_get(string_value);
    if (status <= 0 || string_value != "queued" || mbx.num() != 0)
      $fatal(1, "matching try_get status=%0d value=%s count=%0d",
             status, string_value, mbx.num());

    $display("PASSED");
    $finish;
  end
endmodule
