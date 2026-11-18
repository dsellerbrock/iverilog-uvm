// IEEE 1800-2017/2023 16.4 prohibits automatic actuals passed by reference.
class issue442_ref_base;
  virtual task report(const ref int value);
    $display("%0d", value);
  endtask
endclass

module issue442_deferred_virtual_ref_fail;
  issue442_ref_base receiver;
  initial begin
    automatic int value = 1;
    receiver = new;
    assert #0 (1) receiver.report(value);
  end
endmodule
