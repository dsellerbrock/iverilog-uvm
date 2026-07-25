// M5-6: a MODPORT-QUALIFIED virtual interface type — `virtual iface.mp v'
// (IEEE 1800-2017 25.9, syntax A.2.2.1
// `virtual [interface] interface_identifier [param] [. modport]').
//
// This was a hard SYNTAX ERROR in every declaration context, which made
// the standard UVM agent idiom
//
//     class driver;
//       virtual bus_if.drv vif;
//     endclass
//
// unwritable — the plain `virtual bus_if vif;' form had to be used
// instead. The modport-qualified form now parses as a class property, a
// module-scope variable and a package-scope variable, in both the
// resolved (TYPE_IDENTIFIER) and forward-referenced (IDENTIFIER) shapes,
// and with an optional parameter override before the modport.
//
// Boundary, stated rather than implied: the modport NAME is recorded on
// the type but its direction restrictions are NOT enforced — a handle
// declared `virtual bus_if.mon' can still write. What is accepted is a
// superset of the modport's view, so no conformant design is rejected;
// direction enforcement through a modport-qualified handle is separate
// work (M12-6 already carries the modport direction metadata that it
// would consult). Grammar cost: zero new conflicts (494 shift/reduce,
// 1161 reduce/reduce, unchanged).

interface bus_if;
  bit [7:0] data;
  bit [7:0] arr[4];
  bit       clk;

  modport drv (output data, output arr, input clk);
  modport mon (input data, input arr, input clk);

  task send(bit [7:0] v); data = v; endtask
endinterface

class driver;
  virtual bus_if.drv vif;                       // class property
  function void put(bit [7:0] v); vif.data = v; endfunction
  function void put_arr(int i, bit [7:0] v); vif.arr[i] = v; endfunction
  task call_send(bit [7:0] v); vif.send(v); endtask
endclass

class monitor;
  virtual bus_if.mon vif;
  function bit [7:0] peek();          return vif.data;   endfunction
  function bit [7:0] peek_arr(int i); return vif.arr[i]; endfunction
endclass

module main;

  bus_if sif();

  driver  d;
  monitor m;

  virtual bus_if.drv mvif;      // module-scope, modport-qualified
  virtual bus_if     plain;     // the unqualified form must still work

  int fails = 0;

  initial begin
    d = new();
    m = new();

    d.vif = sif;
    m.vif = sif;
    mvif  = sif;
    plain = sif;

    d.put(8'd42);
    if (sif.data !== 8'd42) begin
      fails++;
      $display("FAILED -- write through a modport-qualified class property: data=%0d (want 42)",
               sif.data);
    end
    if (m.peek() !== 8'd42) begin
      fails++;
      $display("FAILED -- read through a modport-qualified class property: %0d (want 42)",
               m.peek());
    end

    d.put_arr(2, 8'd77);
    if (sif.arr[2] !== 8'd77) begin
      fails++;
      $display("FAILED -- array write through a modport-qualified handle: arr[2]=%0d (want 77)",
               sif.arr[2]);
    end
    if (m.peek_arr(2) !== 8'd77) begin
      fails++;
      $display("FAILED -- array read through a modport-qualified handle: %0d (want 77)",
               m.peek_arr(2));
    end

    d.call_send(8'd11);
    if (sif.data !== 8'd11) begin
      fails++;
      $display("FAILED -- interface task through a modport-qualified handle: data=%0d (want 11)",
               sif.data);
    end

    mvif.send(8'd9);
    if (sif.data !== 8'd9) begin
      fails++;
      $display("FAILED -- module-scope modport-qualified handle: data=%0d (want 9)", sif.data);
    end

    plain.data = 8'd3;
    if (sif.data !== 8'd3) begin
      fails++;
      $display("FAILED -- the unqualified virtual interface form regressed: data=%0d (want 3)",
               sif.data);
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
