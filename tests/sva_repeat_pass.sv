// S6 step 4: `b[*N]` consecutive repetition - should HOLD when b stays 1.
//
// Caveat: any attempt started in the last (N-1) cycles before b drops
// will still be in flight at deadline.  This test holds b=1 through
// $finish so no late-started attempt deadline-misses.
module top;
    bit clk = 0;
    bit b;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) b[*3])
        else begin err++; $display(":assert: False  // b[*3] fired t=%0t b=%0d", $time, b); end

    initial begin
        b <= 0;
        @(posedge clk);                            // t=5 b=0; no attempt
        @(posedge clk);                            // t=15
        b <= 1;
        @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk);
        @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk);
        // 8 cycles of b=1 sampled.  All overlapping attempts match.
        if (err == 0) $display("PASS: b[*3] holds during 8-cycle b=1 run");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
