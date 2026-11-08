module issue2790_assoc_inside;
  logic [3:0] AS[string];
  logic [3:0] AI[int];
  logic [3:0] AX[int];
  logic [3:0] AM[int];
  bit [3:0] BS[string];
  bit ss, sm, is0, isb, bs0;
  logic xhit;
  bit wh, xmiss;

  initial begin
    AS["a"] = 4'b0000;
    AS["b"] = 4'b1011;
    AI[1] = 4'b0000;
    AI[2] = 4'b1011;
    AX[1] = 4'b1011;
    AX[2] = 4'bx010;
    AM[1] = 4'b1010;
    BS["a"] = 4'b0000;

    ss = 4'b1011 inside {AS};
    sm = 4'b0101 inside {AS};
    is0 = 4'b0000 inside {AI};
    isb = 4'b1011 inside {AI};
    bs0 = 4'b0000 inside {BS};
    xhit = 4'bx011 inside {AX};
    wh = 4'b0010 inside {AX};
    xmiss = 4'bx011 inside {AM};

    if (ss !== 1'b1 || sm !== 1'b0 || is0 !== 1'b1
        || isb !== 1'b1 || bs0 !== 1'b1 || xhit !== 1'bx || wh !== 1'b1
        || xmiss !== 1'b0)
      $fatal(1, "associative-array inside traversal failed");
    $display("assoc %0d %0d %0d %0d %0d %b %0d %0d", ss, sm, is0, isb, bs0, xhit, wh, xmiss);
  end
endmodule
