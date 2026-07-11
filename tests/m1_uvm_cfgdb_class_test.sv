// M1 / G24 UVM-level regression: class-valued uvm_config_db set/get round trip.
import uvm_pkg::*;
`include "uvm_macros.svh"

class my_cfg extends uvm_object;
  `uvm_object_utils(my_cfg)
  int magic = 0;
  function new(string name = "my_cfg");
    super.new(name);
  endfunction
endclass

module m1_uvm_cfgdb_class_test;
  initial begin
    my_cfg put_c, got_c;
    put_c = new("the_cfg");
    put_c.magic = 77;

    uvm_config_db#(my_cfg)::set(null, "*", "cfg", put_c);
    if (!uvm_config_db#(my_cfg)::get(null, "", "cfg", got_c))
      $display("FAIL: config_db get returned 0");
    else if (got_c == null) $display("FAIL: got null handle");
    else if (got_c.magic !== 77) $display("FAIL: magic=%0d", got_c.magic);
    else if (got_c != put_c) $display("FAIL: handle mismatch");
    else $display("PASS cfgdb");
    $finish;
  end
endmodule
