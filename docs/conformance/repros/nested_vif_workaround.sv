interface child_if;
  logic value;
  task automatic drive(input logic next_value);
    value = next_value;
  endtask
endinterface

interface parent_if;
  child_if child();
  child_if sibling();
endinterface

module top;
  parent_if actual();

  class driver;
    virtual parent_if vif;
    task automatic run();
      virtual child_if selected;
      selected = vif.child;
      selected.value = 1'b1;
      if (selected.value !== 1'b1) $fatal(1, "nested readback");
      selected = vif.sibling;
      selected.drive(1'b1);
      if (selected.value !== 1'b1) $fatal(1, "nested task readback");
    endtask
  endclass

  driver d;
  initial begin
    d = new;
    d.vif = actual;
    d.run();
    if (actual.child.value !== 1'b1 || actual.sibling.value !== 1'b1)
      $fatal(1, "physical child unchanged");
    $display("PASS nested virtual interface workaround");
  end
endmodule
