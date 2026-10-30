interface bus;
  logic x;
endinterface

module top;
  bus b();
  class C;
    virtual interface bus vif;
  endclass
  C obj;

  initial begin
    obj = new;
    obj.vif = b;
    #0;
    $probe_vif_class_member;
    $finish;
  end
endmodule
