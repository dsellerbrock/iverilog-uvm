// Member access through a class-handle member of an unpacked struct
// (a.h.v): reads, $display arguments, if-conditions, two-deep nesting,
// and method calls through the handle. Pre-fix (recovery D12), the
// READ elaborated to nullptr with no diagnostic: assignments vanished
// (zero instructions emitted), $display arguments were replaced by a
// blank-string stub (printing 32, the ASCII space), and if-conditions
// were force-compiled to the else branch. The write side worked all
// along, making the wrong reads look like lost writes.
module main;
  class Obj;
    int v;
    function void bump(); v = v + 1; endfunction
  endclass

  typedef struct { Obj h; int pad; } S;
  typedef struct { S ns; int pad2; } S2;

  S a;
  S2 b;
  Obj alias_h;
  int vv;
  int fails = 0;

  initial begin
    a.h = new;
    b.ns.h = new;

    // read into a local
    a.h.v = 42;
    vv = a.h.v;
    if (vv !== 42) begin fails++; $display("FAILED: read-into-local vv=%0d", vv); end

    // the write really lands (alias control)
    a.h.v = 77;
    alias_h = a.h;
    if (alias_h.v !== 77) begin fails++; $display("FAILED: alias readback %0d", alias_h.v); end

    // void method call through the struct-member handle
    a.h.v = 10;
    a.h.bump();
    if (a.h.v !== 11) begin fails++; $display("FAILED: method call a.h.v=%0d", a.h.v); end

    // two structs deep
    b.ns.h.v = 123;
    vv = b.ns.h.v;
    if (vv !== 123) begin fails++; $display("FAILED: nested read vv=%0d", vv); end

    // if-condition on the nested read
    a.h.v = 5;
    if (a.h.v == 5) ; else begin fails++; $display("FAILED: if-cond a.h.v=%0d", a.h.v); end

    // direct $display argument (pre-fix printed 32 regardless of value)
    a.h.v = 99;
    if (a.h.v !== 99) begin fails++; $display("FAILED: direct arg a.h.v=%0d", a.h.v); end

    // expression context
    vv = a.h.v + b.ns.h.v;
    if (vv !== 222) begin fails++; $display("FAILED: sum=%0d", vv); end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
