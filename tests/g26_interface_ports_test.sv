// M5 (interfaces/modports): G26-G29 close-out.
//
// - Foundation: a module port of interface type (`bus_if m`) is a
//   handle to the interface instance (IEEE 1800-2017 25.3). It was
//   previously degraded to a 32-bit wire ("Can not find the scope
//   type definition" fallback); it now elaborates as an
//   interface-class variable and the instantiation binds it with an
//   init-scheduled `formal = <vif of actual>` assignment.
// - G26: `import task_name` (and prototype forms) in a modport
//   declaration errored with a hard sorry; now accepted and recorded
//   (25.5.4). Access is not restricted in this implementation.
// - G27: implicit modport selection — a plain instance actual binds
//   a modport-qualified formal.
// - G29: `b.mst` (instance.modport) actuals bind; the modport select
//   binds the whole instance (direction enforcement is a recorded
//   follow-up).
// - G28: interface instance arrays `bus_if b[2]()` with per-element
//   hierarchical access and virtual-interface array binding.
// - nodangle: interface members with no static references inside the
//   interface used to be deleted as unlinked signals, breaking the
//   runtime by-name resolution that virtual-interface handles use.
//
// KNOWN LIMITATION (pre-existing, recorded): interface TASK dispatch
// through handles attaches to a single instance per interface type
// (the elaborated interface class binds one class_scope), so a task
// called through a vif/port handle always runs against that instance.
// The array section below therefore uses a separate interface type;
// dynamic per-handle task dispatch is a recorded follow-up.

interface g26_bus;
  logic [7:0] data;
  logic valid;
  task do_write(input logic [7:0] d);
    data = d;
    valid = 1;
  endtask
  modport mst (output data, output valid, import do_write);
  modport slv (input data, input valid);
endinterface

module g26_producer (g26_bus.mst m);
  initial begin
    #1 m.do_write(8'hA5);   // interface task through a modport port
  end
endmodule

module g26_consumer (g26_bus.slv s);
  logic [7:0] seen_data;
  logic seen_valid;
  initial begin
    #2 seen_data = s.data;
    seen_valid = s.valid;
  end
endmodule

interface g28_lane;
  logic [7:0] data;
endinterface

class g26_holder;
  virtual g28_lane vifs[2];
endclass

module g26_interface_ports_test;
  g26_bus b();          // single instance
  g28_lane arr[2]();    // G28: instance array
  g26_holder h;
  int errors = 0;

  g26_producer p (b.mst);   // G29: instance.modport actual
  g26_consumer c (b);       // G27: implicit modport

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    #3;
    // producer wrote through the modport port; visible on the instance
    check(b.data == 8'hA5 && b.valid === 1'b1,
          "modport port write reached the instance");
    // consumer sampled through its port
    check(c.seen_data == 8'hA5 && c.seen_valid === 1'b1,
          "modport port read saw the instance state");

    // G28: instance array elements are independent
    arr[0].data = 8'h11;
    arr[1].data = 8'h22;
    #1;
    check(arr[0].data == 8'h11 && arr[1].data == 8'h22,
          "interface instance array elements");

    // G28: virtual-interface array binding
    h = new;
    h.vifs[0] = arr[0];
    h.vifs[1] = arr[1];
    h.vifs[0].data = 8'hAA;
    h.vifs[1].data = 8'hBB;
    #1;
    check(arr[0].data == 8'hAA && arr[1].data == 8'hBB,
          "virtual interface array writes");

    if (errors == 0)
      $display("PASSED: all g26 interface port checks");
    else
      $display("FAILED: %0d g26 checks", errors);
    $finish(0);
  end
endmodule
