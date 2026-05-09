// S5 step 4: intersect((req ##5 gnt0), (req ##[1:9] gnt1)) - matches at d=5 only.
module top;
    bit clk = 0;
    bit req, gnt0, gnt1;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) (req ##5 gnt0) intersect (req ##[1:9] gnt1))
        else begin err++; $display(":assert: False  // intersect fired t=%0t", $time); end

    initial begin
        req <= 0; gnt0 <= 0; gnt1 <= 0;
        @(posedge clk);
        req <= 1;
        @(posedge clk); req <= 0;
        @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk);
        gnt0 <= 1; gnt1 <= 1;
        @(posedge clk);                            // both at d=5 → match
        gnt0 <= 0; gnt1 <= 0;
        @(posedge clk); @(posedge clk);
        if (err == 0) $display("PASS: intersect with mixed fixed/range delays");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
