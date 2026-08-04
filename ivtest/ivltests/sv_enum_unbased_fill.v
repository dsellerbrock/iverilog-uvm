`begin_keywords "1800-2012"

// OpenTitan's generated wrappers tie off strongly typed lc_tx_t enum signals
// with an unbased unsized fill literal. Slang and the project's production
// tool flows context-size this spelling; it must not be confused with an
// ordinary integral literal, which still requires an explicit enum cast.
module main;
  typedef enum logic [3:0] {
    On  = 4'b0101,
    Off = 4'b1010
  } lc_tx_t;

  lc_tx_t tied_zero;
  logic [3:0] observed;

  assign tied_zero = '0;
  assign observed = tied_zero;

  (* ivl_synthesis_off *)
  initial begin
    #1;
    if (observed !== 4'b0000) begin
      $display("FAILED -- enum unbased fill produced %b", observed);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
