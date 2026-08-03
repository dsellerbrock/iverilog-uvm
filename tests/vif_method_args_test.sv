// IEEE 1800-2017 25.10: a method call through a virtual interface must
// dispatch to the bound interface instance and pass every user argument.
// A void function still has a return port in the compiler IR, so its first
// user argument is port one rather than port zero.

interface vif_method_args_if;
  int value;

  function automatic void set_value(int v);
    value = v;
  endfunction

  task automatic add_value(int v);
    value += v;
  endtask
endinterface

class vif_method_args_driver;
  virtual vif_method_args_if vif;

  function void set_and_add(int set_v, int add_v);
    vif.set_value(set_v);
    vif.add_value(add_v);
  endfunction
endclass

module vif_method_args_test;
  vif_method_args_if if0();
  vif_method_args_if if1();
  vif_method_args_driver drv;
  int errors;

  initial begin
    drv = new;

    drv.vif = if0;
    drv.set_and_add(17, 4);
    if (if0.value != 21) begin
      errors++;
      $display("FAILED: if0 value=%0d expected=21", if0.value);
    end
    if (if1.value != 0) begin
      errors++;
      $display("FAILED: unbound if1 changed to %0d", if1.value);
    end

    drv.vif = if1;
    drv.set_and_add(31, 6);
    if (if1.value != 37) begin
      errors++;
      $display("FAILED: if1 value=%0d expected=37", if1.value);
    end
    if (if0.value != 21) begin
      errors++;
      $display("FAILED: prior if0 changed to %0d", if0.value);
    end

    if (errors == 0)
      $display("PASSED: virtual-interface method arguments and dispatch");
    else
      $display("FAILED: %0d virtual-interface method argument checks", errors);
    $finish;
  end
endmodule
