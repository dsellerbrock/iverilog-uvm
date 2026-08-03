`begin_keywords "1800-2012"

module main;
  logic [31:0] operand;
  logic [31:0] values [2];

  // Ibex assigns an aggregate to a whole unpacked-array output inside an
  // always_comb process. Synthesis must lower each array word using the word's
  // vector width rather than treating the aggregate width as one packed word.
  always_comb values = '{operand, 32'h0};

  (* ivl_synthesis_off *)
  initial begin
    operand = 32'h1234_5678;
    #1;
    if (values[0] !== 32'h1234_5678 || values[1] !== 32'h0) begin
      $display("FAILED -- first values=%h/%h", values[0], values[1]);
      $finish;
    end

    operand = 32'hdead_beef;
    #1;
    if (values[0] !== 32'hdead_beef || values[1] !== 32'h0) begin
      $display("FAILED -- second values=%h/%h", values[0], values[1]);
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
