`include "uvm_macros.svh"
import uvm_pkg::*;

// A simple sequence item with rand fields and constraints
class my_item extends uvm_sequence_item;
  rand bit [7:0] data;
  rand bit [3:0] addr;
  rand bit [15:0] big_val;

  // data must be in [10, 50]
  constraint c_data { data inside {[8'd10:8'd50]}; }

  // addr must be < 8
  constraint c_addr { addr < 4'd8; }

  // big_val must be >= 100 and <= 200
  constraint c_big  { big_val >= 16'd100; big_val <= 16'd200; }

  `uvm_object_utils(my_item)

  function new(string name = "my_item");
    super.new(name);
  endfunction
endclass

class constraint_test extends uvm_test;
  `uvm_component_utils(constraint_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    my_item item;
    int ok = 1;

    phase.raise_objection(this);
    item = my_item::type_id::create("item");

    repeat (10) begin
      void'(item.randomize());
      $display("data=%0d addr=%0d big_val=%0d", item.data, item.addr, item.big_val);

      if (item.data < 10 || item.data > 50) begin
        $display("FAIL: data=%0d out of range [10,50]", item.data);
        ok = 0;
      end
      if (item.addr >= 8) begin
        $display("FAIL: addr=%0d >= 8", item.addr);
        ok = 0;
      end
      if (item.big_val < 100 || item.big_val > 200) begin
        $display("FAIL: big_val=%0d out of range [100,200]", item.big_val);
        ok = 0;
      end
    end

    if (ok)
      $display("Constraint test PASSED!");
    else
      $display("Constraint test FAILED!");

    phase.drop_objection(this);
  endtask
endclass

module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  initial begin
    run_test("constraint_test");
  end
endmodule
