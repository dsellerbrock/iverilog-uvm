// Waiters on process::await() and on a class property wake in the order
// they began waiting (IEEE 1800-2017 4.7 leaves the order open; VVP keeps
// the event wait-list rule so the order does not depend on allocation).
interface pins_if;
  logic a = 0, b = 0;
endinterface
class flag_c;
  bit up;
endclass
module main;
  process p;
  flag_c f = new;
  string await_log = "", prop_log = "", vif_log = "";
  pins_if pins();
  virtual pins_if vif = pins;
  initial begin
    p = process::self();
    #10;
  end
  for (genvar i = 0; i < 6; i++) begin : g
    initial begin
      #(6 - i);              // later-created blocks start waiting first
      p.await();
      await_log = {await_log, $sformatf("%0d", i)};
    end
    initial begin
      #(20 - i);
      wait (f.up);
      prop_log = {prop_log, $sformatf("%0d", i)};
    end
    initial begin
      #(40 - i);
      @(vif.a or vif.b);
      vif_log = {vif_log, $sformatf("%0d", i)};
    end
  end
  initial begin
    #30 f.up = 1;
    #20 pins.b = 1;
    #1;
    $display("await order %s", await_log);
    $display("prop order %s", prop_log);
    $display("vif order %s", vif_log);
    if (await_log == "543210" && prop_log == "543210" && vif_log == "543210")
      $display("PASSED");
    else $display("FAILED");
  end
endmodule
