// Whole-array assignment pattern into a class property that is an unpacked
// array of a packed (logic) type: `obj.arr = '{ ... }`.
//
// This used to silently miscompile. The property-store code generator
// (show_stmt_assign_sig_cobject) routed the array-pattern r-value through
// draw_eval_vec4, which cannot evaluate an assignment pattern (it is not a
// single vector); it fell through to a "zero fallback", so the array was
// left as 0/x instead of the pattern values. Element-wise assignment
// (arr[i] = ...) always worked, which is what this test contrasts against.
//
// The fix stores each pattern element to its own word via %store/prop/v/i.
// Covers unpacked arrays of packed struct, plain int arrays, and a
// two-dimensional unpacked array (nested pattern), each read back by
// element. Prints PASSED only if every element matches.

module sv_class_prop_array_pattern;

  typedef struct packed { logic [7:0] a; logic [7:0] b; } pair_t;

  class C;
    pair_t ps [3];      // unpacked array of packed struct
    int    iv [3];      // unpacked array of int
    pair_t m  [2][2];   // 2-D unpacked array of packed struct

    function void fill();
      ps = '{ '{a:8'h10, b:8'h20}, '{a:8'h30, b:8'h40}, '{a:8'h50, b:8'h60} };
      iv = '{ 100, 200, 300 };
      m  = '{ '{'{8'h1,8'h2}, '{8'h3,8'h4}},
              '{'{8'h5,8'h6}, '{8'h7,8'h8}} };
    endfunction
  endclass

  int errors = 0;

  initial begin
    C c = new;
    c.fill();

    if (c.ps[0] !== 16'h1020) begin $display("FAIL ps[0]=%h", c.ps[0]); errors++; end
    if (c.ps[1] !== 16'h3040) begin $display("FAIL ps[1]=%h", c.ps[1]); errors++; end
    if (c.ps[2] !== 16'h5060) begin $display("FAIL ps[2]=%h", c.ps[2]); errors++; end

    if (c.iv[0] !== 100) begin $display("FAIL iv[0]=%0d", c.iv[0]); errors++; end
    if (c.iv[1] !== 200) begin $display("FAIL iv[1]=%0d", c.iv[1]); errors++; end
    if (c.iv[2] !== 300) begin $display("FAIL iv[2]=%0d", c.iv[2]); errors++; end

    if (c.m[0][0] !== 16'h0102) begin $display("FAIL m[0][0]=%h", c.m[0][0]); errors++; end
    if (c.m[0][1] !== 16'h0304) begin $display("FAIL m[0][1]=%h", c.m[0][1]); errors++; end
    if (c.m[1][0] !== 16'h0506) begin $display("FAIL m[1][0]=%h", c.m[1][0]); errors++; end
    if (c.m[1][1] !== 16'h0708) begin $display("FAIL m[1][1]=%h", c.m[1][1]); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
