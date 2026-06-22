// Accessing an element of a dynamic-array-of-objects CLASS PROPERTY, then a
// field of that element: obj.darray_prop[i].field, including inside a foreach.
//
// eval_object_select handled assoc- and queue-of-objects property elements but
// a dynamic array fell through to the fixed-array %prop/obj path, which cannot
// index a dynamic array: it left the whole darray on the stack ("%prop/* on
// darray receiver ... using default value fallback") and then read/crashed.
// This is the UVM uvm_reg::get_full_hdl_path foreach pattern, hit during
// OpenTitan aon_timer's RAL traversal.
//
// Fix: a new stack-form %load/dar/obj/obj opcode loads element [word3] from the
// darray object on the stack; eval_object_select emits it for a darray-typed
// property element.
module darray_object_property_element_test;
  class item;
    int v;
    function new(int x); v = x; endfunction
  endclass
  class holder;
    item d[];
    function int run();
      int sum = 0;
      d = new[3];
      d[0] = new(10); d[1] = new(20); d[2] = new(30);
      // direct indexed access
      if (d[1].v != 20) return -1;
      // foreach over the darray-of-objects property
      foreach (d[i]) sum += d[i].v;       // 10+20+30 = 60
      return sum;
    endfunction
  endclass
  initial begin
    holder h = new();
    int r = h.run();
    if (r == 60) $display("PASS sum=%0d", r);
    else         $display("FAIL sum=%0d", r);
    $finish;
  end
endmodule
