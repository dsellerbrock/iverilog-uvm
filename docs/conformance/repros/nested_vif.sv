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
      vif.child.value = 1'b1;
      if (vif.child.value !== 1'b1) $fatal(1, "nested readback");
      vif.sibling.drive(1'b1);
      if (vif.sibling.value !== 1'b1) $fatal(1, "nested task readback");
    endtask
  endclass

  driver d;
  initial begin
    d = new;
    d.vif = actual;
    d.run();
    $display("PASS nested virtual interface");
  end
endmodule
