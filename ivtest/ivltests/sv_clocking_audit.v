module sv_clocking_audit;
  bit clk = 0;
  always #5 clk = ~clk;
  logic [7:0] d, drv = 0, q = 0;
  int errors = 0;

  clocking cbn @(negedge clk);
    default input #1step;
    input  d;
    input  cv = d;             // clockvar rename
    output drv;                // edge-aligned output drive
  endclocking

  default clocking dc @(posedge clk); output q; endclocking

  initial begin
    // negedge clocking event + clockvar rename
    d = 8'h11; @(cbn);
    if (cbn.d !== 8'h11) begin $display("FAIL neg-sample %0h", cbn.d); errors++; end
    if (cbn.cv !== 8'h11) begin $display("FAIL rename %0h", cbn.cv); errors++; end

    // #1step Preponed sampling: change d AT the edge, sample sees pre-edge value
    d = 8'h22; @(cbn);
    fork begin @(negedge clk); d = 8'h33; end join_none
    @(cbn);
    if (cbn.d !== 8'h22) begin $display("FAIL preponed %0h (exp 22)", cbn.d); errors++; end
    // sampled value stays stale between edges even though d is now 8'h33
    #1 if (cbn.d !== 8'h22 || d !== 8'h33) begin
      $display("FAIL stale cbn.d=%0h d=%0h", cbn.d, d); errors++; end

    // output drive (issued at the clocking edge) reaches the signal
    @(cbn); cbn.drv <= 8'hEE;
    @(cbn); #1;
    if (drv !== 8'hEE) begin $display("FAIL drive drv=%0h", drv); errors++; end

    // ##N cycle delay via default clocking
    @(dc); q <= 8'h01;
    ##1 if (q !== 8'h01) begin $display("FAIL cyc1 q=%0h", q); errors++; end
    dc.q <= 8'h02;
    ##2 if (q !== 8'h02) begin $display("FAIL cyc2 q=%0h", q); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
