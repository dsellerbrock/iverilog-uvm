// IEEE 1800-2017/2023 13.4.2: a function with no arguments may be called
// without its parentheses.
//
// UVM's uvm_driver.svh:100 relies on it:
//
//     function int size ();        // uvm_port_base.svh:450
//     if (seq_item_port.size < 1)  // uvm_driver.svh:100
//
// `seq_item_port' is a class PROPERTY, so the receiver is a property whose
// type is a class. The parser leaves `obj.m' as a member component rather
// than a PECallFunction, and that path walked properties only: the method
// name matched no property and the read produced 0.
//
// It was SILENT and WRONG, not merely unsupported -- the connectivity check
// above evaluated false on every UVM core, which is what
// `condition expression failed to elaborate; ASSUMING FALSE' reported. The
// same call through a plain object VARIABLE always worked, which is why the
// failure looked shape-dependent.
//
// slang 11.0.448 accepts every form below under both editions.

class port_base;
  int n;
  function new(int v = 3); n = v; endfunction
  function int size (); return n; endfunction
  function int doubled(); return n * 2; endfunction
endclass

class holder;
  port_base p;
  int tag = 7;
  function new(int v = 3); p = new(v); endfunction
  // A parenless call on a property from INSIDE the owning class, which is
  // the uvm_driver spelling (implicit this).
  function bit connected(); return p.size >= 1; endfunction
endclass

module main;

  int errors = 0;

  task automatic chk(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAILED: %s got %0d want %0d", what, got, exp);
      errors += 1;
    end
  endtask

  port_base direct;
  holder h;
  holder empty;

  initial begin
    direct = new(3);
    h      = new(3);
    empty  = new(0);

    // Control: through a plain object variable. This path always worked.
    chk("direct.size()", direct.size(), 3);
    chk("direct.size",   direct.size,   3);

    // The regression: through a class PROPERTY.
    chk("h.p.size()",    h.p.size(),    3);
    chk("h.p.size",      h.p.size,      3);
    chk("h.p.doubled",   h.p.doubled,   6);

    // In a CONDITION, which is the uvm_driver shape and where the failure
    // surfaced as "ASSUMING FALSE".
    if (!(h.p.size >= 1))    begin $display("FAILED: condition >= 1"); errors += 1; end
    if (h.p.size < 1)        begin $display("FAILED: condition < 1 taken"); errors += 1; end
    if (!(empty.p.size < 1)) begin $display("FAILED: empty should be < 1"); errors += 1; end

    // From inside the owning class, via implicit this.
    if (!h.connected())     begin $display("FAILED: h.connected()"); errors += 1; end
    if (empty.connected())  begin $display("FAILED: empty.connected()"); errors += 1; end

    // An ordinary property read through the same path must be unaffected.
    chk("h.tag", h.tag, 7);

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
