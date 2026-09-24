class csrng_macro_leaf;
  rand bit [7:0] code;
  constraint mubi_style_dist_c {
    if (8'hD3 > 8'h2C) {
      code dist {
        8'hD3 := 2,
        8'h2C := 2,
        [8'h00:8'h2B] := 1,
        [8'h2D:8'hD2] := 1,
        [8'hD4:8'hFF] := 1
      };
    } else {
      code dist {
        8'hD3 := 2,
        8'h2C := 2,
        [8'h00:8'h2B] := 1,
        [8'h2D:8'hD2] := 1,
        [8'hD4:8'hFF] := 1
      };
    }
  }
endclass
class csrng_macro_root;
  rand csrng_macro_leaf a;
  rand csrng_macro_leaf b;
  function new(); a = new(); b = new(); endfunction
  constraint same_c { a.code == b.code; }
endclass
module csrng_macro_guard_red;
  initial begin
    csrng_macro_root root = new();
    if (root.randomize()) $fatal(1, "expected current joint guarded-dist limitation");
    $display("PASS reproduced macro-style guarded joint-dist RED");
    $finish;
  end
endmodule
