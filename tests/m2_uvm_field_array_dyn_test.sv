// G25 probe: uvm_field_sarray_int copy/clone propagation (UVM field
// automation; Accellera reference behavior).
import uvm_pkg::*;
`include "uvm_macros.svh"

class txn extends uvm_object;
  int arr[];
  int scalar;
  `uvm_object_utils_begin(txn)
    `uvm_field_array_int(arr, UVM_ALL_ON)
    `uvm_field_int(scalar, UVM_ALL_ON)
  `uvm_object_utils_end
  function new(string name = "txn");
    super.new(name);
  endfunction
endclass

module m2_uvm_field_array_dyn_test;
  initial begin
    txn a, b;
    uvm_object o;
    int errors = 0;

    a = new("a");
    a.arr = new[4]; foreach (a.arr[i]) a.arr[i] = 10 * (i + 1);
    a.scalar = 99;

    o = a.clone();
    if (o == null) begin
      $display("FAIL: clone returned null");
      errors++;
    end else if (!$cast(b, o)) begin
      $display("FAIL: cast of clone failed");
      errors++;
    end else begin
      if (b.scalar !== 99) begin
        $display("FAIL: scalar not copied (%0d)", b.scalar);
        errors++;
      end
      foreach (b.arr[i]) begin
        if (b.arr[i] !== 10 * (i + 1)) begin
          $display("FAIL: arr[%0d] = %0d, expected %0d", i, b.arr[i], 10 * (i + 1));
          errors++;
        end
      end
    end

    if (errors == 0) $display("PASS g25-dyn");
    $finish;
  end
endmodule
