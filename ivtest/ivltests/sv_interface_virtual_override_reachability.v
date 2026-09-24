`timescale 1ns/1ps

interface override_if;
  logic value;
  task drive(); value = 1'b1; endtask
endinterface

class override_base;
  virtual task go(); $display("BASE CALLED"); endtask
endclass

class override_clean extends override_base;
  virtual task go(); $display("CLEAN CALLED"); endtask
endclass

class override_derived extends override_base;
  virtual override_if vif;
  virtual task go();
    $display("DERIVED CALLED");
    vif.drive();
  endtask
endclass

class override_mid extends override_base;
endclass

class override_leaf extends override_mid;
  virtual override_if vif;
  virtual task go(); vif.drive(); endtask
endclass

class override_super_writer extends override_base;
  virtual override_if vif;
  virtual task go(); vif.drive(); endtask
  task call_base(); super.go(); endtask
endclass

module override_via_base;
  override_if bus();
  assign bus.value = 1'b0;
  override_base base;
  override_derived derived;
  initial begin
    derived = new();
    derived.vif = bus;
    base = derived;
    base.go();
    #1;
    $display("value=%b", bus.value);
  end
endmodule

module override_no_call;
  override_if bus();
  assign bus.value = 1'b0;
  override_base base;
  override_derived derived;
  initial begin
    derived = new();
    derived.vif = bus;
    base = derived;
    #1;
    $display("value=%b", bus.value);
  end
endmodule

module override_direct_call;
  override_if bus();
  assign bus.value = 1'b0;
  override_derived derived;
  initial begin
    derived = new();
    derived.vif = bus;
    derived.go();
  end
endmodule

class nonvirtual_c;
  virtual override_if vif;
  task go(); vif.drive(); endtask
endclass

module nonvirtual_call;
  override_if bus();
  assign bus.value = 1'b0;
  nonvirtual_c obj;
  initial begin
    obj = new();
    obj.vif = bus;
    obj.go();
  end
endmodule

module override_transitive;
  override_if bus();
  assign bus.value = 1'b0;
  override_base base;
  override_leaf leaf;
  initial begin
    leaf = new();
    leaf.vif = bus;
    base = leaf;
    base.go();
  end
endmodule

module override_uncertain;
  override_if bus();
  assign bus.value = 1'b0;
  override_base base;
  override_clean clean;
  override_derived writer;
  initial begin
    clean = new();
    writer = new();
    writer.vif = bus;
    if ($test$plusargs("WRITER")) base = writer;
    else base = clean;
    base.go();
  end
endmodule

module override_super_only;
  override_if bus();
  assign bus.value = 1'b0;
  override_super_writer obj;
  initial begin
    obj = new();
    obj.vif = bus;
    obj.call_base();
    #1;
    $display("value=%b", bus.value);
  end
endmodule
