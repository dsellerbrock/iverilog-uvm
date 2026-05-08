// S2: $rose — should NOT fire.  `q` gets posedge after d==1.
module top;
    bit clk = 0;
    bit d, q;
    int err = 0;
    always #5 clk = ~clk;
    always_ff @(posedge clk) q <= d;

    // When q rises, d must have been 1 last cycle (it's now equal to old d).
    // Equivalent: $rose(q) implies $past(d) == 1.
    assert property (@(posedge clk) $rose(q) |-> q == 1)
        else begin err++; $display(":assert: False  // $rose at t=%0t q=%0d", $time, q); end

    initial begin
        d <= 0;
        @(posedge clk);
        d <= 1; @(posedge clk);    // q<=1, $rose(q) next cycle
        d <= 1; @(posedge clk);    // q rises here, $rose=1, q==1, no fire
        d <= 0; @(posedge clk);
        d <= 0; @(posedge clk);
        if (err == 0) $display("PASS: $rose case ok");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
