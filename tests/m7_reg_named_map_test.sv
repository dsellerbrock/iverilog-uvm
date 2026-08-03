// Exercise the OpenTitan RAL construction shape: named arguments create the
// sole map, add a register, and later recover that map through the register's
// object-keyed associative array.
`include "uvm_macros.svh"
import uvm_pkg::*;

class named_map_reg extends uvm_reg;
  `uvm_object_utils(named_map_reg)
  uvm_reg_field fld;

  function new(string name = "named_map_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  function void build();
    fld = uvm_reg_field::type_id::create("fld");
    fld.configure(this, 1, 4, "RO", 1, 0, 1, 0, 0);
  endfunction
endclass

class named_map_block extends uvm_reg_block;
  `uvm_object_utils(named_map_block)
  named_map_reg status;

  function new(string name = "named_map_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  function void build();
    default_map = create_map(.name("default_map"),
                             .base_addr(64'h1000),
                             .n_bytes(4),
                             .endian(UVM_LITTLE_ENDIAN));
    status = named_map_reg::type_id::create("status");
    status.configure(this, null, "");
    status.build();
    default_map.add_reg(.rg(status), .offset(64'h14));
    lock_model();
  endfunction
endclass

module m7_reg_named_map_test;
  initial begin
    named_map_block blk = new("blk");
    uvm_reg_map from_reg;
    uvm_reg_map_info info;
    int bad = 0;

    blk.build();
    from_reg = blk.status.get_default_map();
    if (blk.default_map == null) begin
      $display("FAIL: block default map is null");
      bad++;
    end else if (blk.default_map.get_name() != "default_map") begin
      $display("FAIL: block map name is '%s'", blk.default_map.get_name());
      bad++;
    end
    if (from_reg == null) begin
      $display("FAIL: register default map is null");
      bad++;
    end else begin
      if (from_reg != blk.default_map) begin
        $display("FAIL: register recovered a different map ('%s')",
                 from_reg.get_name());
        bad++;
      end
      info = from_reg.get_reg_map_info(blk.status, 0);
      if (info == null) begin
        $display("FAIL: recovered map does not contain status");
        bad++;
      end
    end

    if (bad == 0)
      $display("PASSED: named RAL map construction and recovery");
    $finish;
  end
endmodule
