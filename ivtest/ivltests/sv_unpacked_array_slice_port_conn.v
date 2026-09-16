// A range select on a single-dimension fixed unpacked array
// (`arr[hi:lo]`, selecting a contiguous sub-array of the same element
// type) used as a module port-connection actual. Confirmed
// independently: slang (--std 1800-2017) accepts this, 0 errors, 0
// warnings.
//
// Real, unmodified Caliptra formal-verification RTL relies on exactly
// this shape (submodules/adams-bridge/src/ntt_top/rtl/
// ntt_masked_special_adder.sv and .../abr_libs/rtl/
// abr_masked_add_sub_mod_Boolean.sv both connect e.g.
// `r0_c0_delayed[WIDTH-1:0]` -- a WIDTH-element slice out of a
// WIDTH+1-element unpacked array -- straight to a module port). Before
// this fix it was rejected with "sorry: Array slices are not yet
// supported for continuous assignment." even though the construct is
// legal. This single gap was the only thing blocking Icarus from
// compiling Caliptra's full-chip `caliptra_top` integration target at
// all.
//
// This regression checks actual wiring correctness (element-by-element
// values, exclusion of the out-of-range element, and live propagation
// of a post-elaboration change through the connection), not just
// compile success -- a naive fix that merely accepted the syntax while
// wiring the wrong pins would still "pass" a compile-only check.
module sub #(parameter WIDTH = 4) (
  input [1:0] r0 [WIDTH-1:0]
);
endmodule

module main;
  logic [1:0] arr [4:0];  // 5 elements: [4:0]
  int fails = 0;

  sub #(.WIDTH(4)) u_sub (
    .r0(arr[3:0])          // slice: elements 3..0 (4 of the 5), excludes arr[4]
  );

  initial begin
    arr[0] = 2'b00;
    arr[1] = 2'b01;
    arr[2] = 2'b10;
    arr[3] = 2'b11;
    arr[4] = 2'b01;
    #1;
    if (u_sub.r0[0] !== 2'b00) begin $display("FAIL r0[0]=%b", u_sub.r0[0]); fails++; end
    if (u_sub.r0[1] !== 2'b01) begin $display("FAIL r0[1]=%b", u_sub.r0[1]); fails++; end
    if (u_sub.r0[2] !== 2'b10) begin $display("FAIL r0[2]=%b", u_sub.r0[2]); fails++; end
    if (u_sub.r0[3] !== 2'b11) begin $display("FAIL r0[3]=%b", u_sub.r0[3]); fails++; end

    // The out-of-range element must not be part of the slice.
    arr[4] = 2'b00;
    #1;
    if (u_sub.r0[3] !== 2'b11) begin
      $display("FAIL out-of-range element leaked into slice, r0[3]=%b", u_sub.r0[3]);
      fails++;
    end

    // The connection is a live net alias, not a one-shot copy.
    arr[1] = 2'b11;
    #1;
    if (u_sub.r0[1] !== 2'b11) begin
      $display("FAIL live-update did not propagate, r0[1]=%b", u_sub.r0[1]);
      fails++;
    end

    if (fails != 0) begin
      $display("FAILED, fails=%0d", fails);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule
