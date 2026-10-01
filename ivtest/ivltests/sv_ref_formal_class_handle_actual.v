// A `ref' formal bound to a class handle that is not a plain variable -- a class
// property or an array element (IEEE 1800-2017/2023 13.5.2) -- copies the
// handle in and out through a temporary. The copy-in stored the vector image of
// a null test into the object-typed temporary, and the runtime aborted with
// "recv_vec4 not implemented" (OpenTitan usbdev BFM: `out_packet(rx_token,
// data, rsp)` with `rx_token' a class property).
class payload;
  int v;
  function new(int v = 1); this.v = v; endfunction
endclass

class holder;
  payload rx;
  payload slots[2];
  int unsigned counter;

  function bit seen(ref payload p);
    return p != null && p.v == 5;
  endfunction

  function bit rebind(ref payload p, output payload made);
    made = new(p.v + 1);
    p = new(p.v + 10);
    return 1;
  endfunction

  // The formal and the property are the same variable (IEEE 1800-2017/2023
  // 13.5.2): a write by the property's own name is seen through the formal and
  // survives the return; a write through the formal is seen by name at once.
  function bit alias_name_write(ref payload p);
    rx = null;
    return p == null;
  endfunction

  function bit alias_formal_write(ref int unsigned n);
    n = 41;
    return counter == 41;
  endfunction

  function bit forward(output payload made);
    return rebind(rx, made);
  endfunction
endclass

module main;
  int errors;
  initial begin
    holder h;
    payload made;
    bit ok;
    h = new;
    h.rx = new(5);
    h.slots[1] = new(5);
    if (!h.seen(h.rx)) begin $display("FAILED property actual"); errors++; end
    if (!h.seen(h.slots[1])) begin $display("FAILED element actual"); errors++; end
    ok = h.forward(made);
    if (!ok || made == null || made.v !== 6) begin $display("FAILED output forward"); errors++; end
    if (h.rx.v !== 15) begin $display("FAILED copy-out of rebound property %0d", h.rx.v); errors++; end
    ok = h.rebind(h.slots[1], made);
    if (!ok || made.v !== 6 || h.slots[1].v !== 15) begin
      $display("FAILED element copy-out %0d %0d", made.v, h.slots[1].v); errors++;
    end
    h.rx = new(5);
    if (!h.alias_name_write(h.rx)) begin $display("FAILED alias via formal"); errors++; end
    if (h.rx !== null) begin $display("FAILED stale copy-out resurrected the handle"); errors++; end
    if (!h.alias_formal_write(h.counter) || h.counter !== 41) begin
      $display("FAILED alias via name"); errors++;
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
