// IEEE 1800-2017 10.9: an assignment pattern has no self-determined
// type -- it takes its type from context. A default port/argument
// value ('{...} used as `= '{...}` in a formal declaration) has no
// surrounding expression to supply that context, so it must be
// elaborated directly against the formal's own declared type.
//
// Two distinct compiler defects, reduced from OpenTitan
// lc_ctrl_scoreboard.sv (packed struct default) and lc_ctrl_if.sv
// (fixed unpacked-array default):
//
// 1) A packed-type default ('{default: ...} for a struct/vector
//    formal) failed outright with "An assignment pattern needs a
//    context that gives it a type; there is none here."
//
// 2) A fixed unpacked-array formal's NetNet::net_type() is only its
//    ELEMENT type (the complete type including dimensions is
//    array_type()); using the element type to elaborate the default
//    built a scalar value instead of a whole-array pattern, and the
//    call-site default-argument path unconditionally padded that
//    value to the port's scalar element width -- corrupting a
//    NetEArrayPattern and crashing the code generator
//    (store_vec4_to_lval assertion) the first time such a default was
//    actually used.
typedef struct packed { logic a; logic [3:0] b; } rec_t;

class C;
  function rec_t f(rec_t x = '{default: 1'b1});
    return x;
  endfunction

  task set(int val, int lens[4] = '{default: 7});
    foreach (lens[i]) begin
      if (lens[i] !== 7) begin
        $display("FAILED lens[%0d]=%0d", i, lens[i]);
        $finish;
      end
    end
  endtask
endclass

module main;
  initial begin
    C c = new;
    rec_t r = c.f();
    if (r.a !== 1'b1 || r.b !== 4'h1) begin
      $display("FAILED a=%b b=%h", r.a, r.b);
      $finish;
    end
    c.set(1);
    $display("PASSED");
  end
endmodule
