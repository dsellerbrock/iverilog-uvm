`include "uvm_macros.svh"
import uvm_pkg::*;

class release_item extends uvm_object;
  int value;
  `uvm_object_utils_begin(release_item)
    `uvm_field_int(value, UVM_DEFAULT)
  `uvm_object_utils_end
  function new(string name="release_item"); super.new(name); endfunction
endclass

class release_test extends uvm_test;
  `uvm_component_utils(release_test)
  bit checked;
  function new(string name="release_test", uvm_component parent=null);
    super.new(name,parent);
  endfunction
  task run_phase(uvm_phase phase);
    release_item item, copied;
    uvm_hdl_data_t data;
    phase.raise_objection(this);
    item=release_item::type_id::create("item");
    item.value=37;
    if (!$cast(copied,item.clone())) `uvm_fatal("CLONE","wrong clone type")
    if (copied.value!=37 || !item.compare(copied))
      `uvm_fatal("COPY","field copy/compare failed")
    copied.value=41;
    if (item.value!=37) `uvm_fatal("ALIAS","clone aliases original")
    if (uvm_re_match("^item_[0-9]+$","item_37")!=0 ||
        uvm_re_match("^item_[0-9]+$","bad")==0)
      `uvm_fatal("REGEX","DPI regex check failed")
    #1;
    if (!uvm_hdl_read("uvm_release_smoke.dut_value",data) || data[31:0]!=32'h13579bdf)
      `uvm_fatal("HDL","DPI HDL read failed")
    checked=1;
    phase.drop_objection(this);
  endtask
  function void report_phase(uvm_phase phase);
    if (!checked) `uvm_fatal("TRAFFIC","run phase did not execute checks")
    $display("UVM_RELEASE_SMOKE_PASSED");
  endfunction
endclass

module uvm_release_smoke;
  logic [31:0] dut_value=32'h13579bdf;
  initial run_test("release_test");
endmodule
