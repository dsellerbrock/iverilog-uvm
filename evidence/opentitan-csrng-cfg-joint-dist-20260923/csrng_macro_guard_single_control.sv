class csrng_macro_single;
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
module csrng_macro_guard_single_control;
  initial begin
    csrng_macro_single item = new();
    repeat (8) if (!item.randomize()) $fatal(1, "single guarded dist should randomize");
    $display("PASS single-owner macro-style guarded dist");
    $finish;
  end
endmodule
