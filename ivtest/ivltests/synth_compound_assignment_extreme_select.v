`begin_keywords "1800-2012"

// IEEE 1800-2023 11.5.1 defines a write through a wholly out-of-bounds
// part-select as having no effect. Constant out-of-range indices may also be
// diagnosed at compile time (Note 2), so this is an Icarus no-crash and
// accepted-behavior regression rather than a cross-tool acceptance test.
// In particular, computing the selected interval must not overflow a host
// signed long or cause synthesis to allocate an enormous carrier.
module synth_compound_assignment_extreme_select;
  logic [7:0] mask;
  logic [7:0] result;

  always_comb begin
    result = mask;
    result[64'sh7fff_ffff_ffff_ffff +: 2] += 2'b01;
    result[64'sh8000_0000_0000_0000 +: 2] ^= 2'b11;
  end

  (* ivl_synthesis_off *)
  initial begin
    mask = 8'h81;
    #1;
    if (result !== 8'h81)
      $fatal(1, "FAILED first result=%h", result);

    mask = 8'h0c;
    #1;
    if (result !== 8'h0c)
      $fatal(1, "FAILED second result=%h", result);

    $display("PASSED");
  end
endmodule

`end_keywords
