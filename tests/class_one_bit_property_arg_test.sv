// Regression: a width-1 class property passed as a system-task/function
// argument (e.g. $display, $sformatf) must be read as its VALUE, not as the
// containing object.
//
// get_vpi_taskfunc_signal_arg() (tgt-vvp/draw_vpi.c) passes a "simple signal"
// argument by its net handle.  For a class PROPERTY the base net is the
// CONTAINING OBJECT, not the property storage.  Wider properties fell back to
// %prop evaluation via a width-mismatch guard, but a width-1 property matched
// the 1-bit object-handle width and slipped through, emitting the object net —
// so $display("%0d", obj.one_bit) printed the class name instead of the bit.
//
// (This corrupted, e.g., the OpenTitan cip_base_scoreboard message
//  "unexpected d_error value (predicted 1, but saw <class name>)".)

module top;
  class item;
    bit        b1;       // width-1
    bit [1:0]  b2;       // width-2 (control: already worked)
    bit        flags[3]; // unrelated
  endclass

  function automatic int check(item it);
    int err = 0;
    string s;
    // %0d / %b of a 1-bit property
    s = $sformatf("%0d", it.b1);
    if (s != "1") begin $display("FAIL: $sformatf %%0d of 1-bit prop = '%s' (want 1)", s); err++; end
    s = $sformatf("%b", it.b1);
    if (s != "1") begin $display("FAIL: $sformatf %%b of 1-bit prop = '%s' (want 1)", s); err++; end
    // 2-bit control
    s = $sformatf("%0d", it.b2);
    if (s != "2") begin $display("FAIL: $sformatf %%0d of 2-bit prop = '%s' (want 2)", s); err++; end
    // read into an automatic local
    begin
      automatic bit loc = it.b1;
      if (loc !== 1'b1) begin $display("FAIL: 1-bit prop read into local = %0d (want 1)", loc); err++; end
    end
    // comparison context
    if (it.b1 != 1'b1) begin $display("FAIL: 1-bit prop != 1 (value wrong)"); err++; end
    return err;
  endfunction

  initial begin
    item it = new();
    int err;
    it.b1 = 1'b1;
    it.b2 = 2'h2;
    err = check(it);
    if (err == 0) $display("PASS");
    else $display("class_one_bit_property_arg_test FAILED with %0d errors", err);
    $finish;
  end
endmodule
