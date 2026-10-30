interface issue1588_bus;
  logic x;
endinterface

module top;
  issue1588_bus b();
  class C;
    virtual interface issue1588_bus vif;
  endclass
  C obj;

  initial begin
    obj = new;
    obj.vif = b;
    #0;
    $probe_virtual_interface_member;
    $finish;
  end
endmodule
