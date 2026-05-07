// G41: static class member array assignment and read-back
// Verifies that static unpacked arrays in a class are correctly
// allocated as multi-word arrays and support element-level read/write.
`include "uvm_macros.svh"
import uvm_pkg::*;

class TrackingClass;
  static int registry[8];
  static int call_count = 0;

  function new(int id);
    registry[call_count] = id;
    call_count++;
  endfunction
endclass

module g41_static_class_array_test;
  TrackingClass objs[4];

  initial begin
    for (int i = 0; i < 4; i++)
      objs[i] = new(i * 10);

    if (TrackingClass::call_count !== 4) begin
      `uvm_error("G41", $sformatf("FAIL: call_count=%0d expected 4",
                                   TrackingClass::call_count))
    end else if (TrackingClass::registry[0] !== 0  ||
                 TrackingClass::registry[1] !== 10 ||
                 TrackingClass::registry[2] !== 20 ||
                 TrackingClass::registry[3] !== 30) begin
      `uvm_error("G41", $sformatf("FAIL: registry=[%0d,%0d,%0d,%0d] expected [0,10,20,30]",
                                   TrackingClass::registry[0],
                                   TrackingClass::registry[1],
                                   TrackingClass::registry[2],
                                   TrackingClass::registry[3]))
    end else begin
      $display("PASS");
    end
  end
endmodule
