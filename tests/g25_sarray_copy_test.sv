// G25 regression test: unpacked static-array property whole-array copy.
// Tests b.data = a.data where data is int[4] (4-element unpacked sarray).

`include "uvm_macros.svh"
import uvm_pkg::*;

class int_arr_item extends uvm_object;
  `uvm_object_utils_begin(int_arr_item)
    `uvm_field_sarray_int(data, UVM_ALL_ON)
  `uvm_object_utils_end

  int data[4];

  function new(string name = "int_arr_item");
    super.new(name);
  endfunction
endclass

module top;
  initial begin
    int_arr_item a, b;
    int_arr_item c;

    a = new("a");
    a.data[0] = 10; a.data[1] = 20; a.data[2] = 30; a.data[3] = 40;

    // Test 1: whole-array direct assignment
    b = new("b");
    b.data = a.data;
    if (b.data[0] !== 10 || b.data[1] !== 20 || b.data[2] !== 30 || b.data[3] !== 40) begin
      $display("FAIL: direct assign b.data=[%0d,%0d,%0d,%0d] expected [10,20,30,40]",
               b.data[0], b.data[1], b.data[2], b.data[3]);
      $finish(1);
    end

    // Test 2: UVM copy() round-trip (uvm_field_sarray_int macro path)
    c = new("c");
    c.copy(a);
    if (c.data[0] !== 10 || c.data[1] !== 20 || c.data[2] !== 30 || c.data[3] !== 40) begin
      $display("FAIL: copy() c.data=[%0d,%0d,%0d,%0d] expected [10,20,30,40]",
               c.data[0], c.data[1], c.data[2], c.data[3]);
      $finish(1);
    end

    $display("PASS");
    $finish;
  end
endmodule
