// IEEE 1800-2017/2023 8.25 with 8.21.
//
// A parameterized class whose type parameter DEFAULTS to a virtual base:
//
//   class registry #(type T = base);
//     static function base make(); T obj; obj = new(); return obj; endfunction
//   endclass
//
// 8.21 forbids instantiating an abstract class, and in the GENERIC body T is
// literally that virtual base -- but that body is a template seed (8.25: "a
// generic class is not a type") and is never executed. Every real
// specialization binds T to a concrete class where `new' is legal. This is
// uvm_component_registry #(T)'s shape.
//
// Icarus used to warn "new of virtual class ... degraded to null" here, once
// per parameterized class, from a body the design never instantiates.
//
// The residual is pinned by sv_class_virtual_new_in_method_fail, which must
// STAY a hard error: `new' on a virtual class in an ORDINARY class method has
// no type parameter that could have collapsed, and 8.21 applies in full.

virtual class base;
  pure virtual function int who();
endclass
class d1 extends base; function int who(); return 1; endfunction endclass
class d2 extends base; function int who(); return 2; endfunction endclass

class registry #(type T = base);
  static function base make(); T obj; obj = new(); return obj; endfunction
endclass

module main;
  int errors = 0;
  base a, b;
  initial begin
    a = registry#(d1)::make();
    b = registry#(d2)::make();

    if (a == null) begin $display("FAILED: registry#(d1) returned null"); errors += 1; end
    if (b == null) begin $display("FAILED: registry#(d2) returned null"); errors += 1; end

    // Distinct specializations must return distinct, correctly typed objects,
    // so the value -- not merely the absence of a warning -- is checked.
    if (a != null && a.who() != 1) begin
      $display("FAILED: d1 who() got %0d want 1", a.who()); errors += 1;
    end
    if (b != null && b.who() != 2) begin
      $display("FAILED: d2 who() got %0d want 2", b.who()); errors += 1;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end
endmodule
