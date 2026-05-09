// S6 step 6: `b[*2:5]` range repetition - should HOLD when b run length is 2..5.
module top;
    bit clk = 0;
    bit b;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) b[*2:5])
        else begin err++; $display(":assert: False  // b[*2:5] fired t=%0t b=%0d", $time, b); end

    initial begin
        b <= 0;
        @(posedge clk);
        b <= 1;                           // start a run
        @(posedge clk); @(posedge clk);   // 2 cycles of b=1 → run of 2 satisfies
        @(posedge clk); @(posedge clk);   // 4 cycles of b=1 → run of 4 satisfies
        @(posedge clk);                   // 5 cycles → boundary
        @(posedge clk); @(posedge clk);   // run might exceed 5; oldest in-flight should still match by then
        if (err == 0) $display("PASS: b[*2:5] holds in 2-5 cycle b=1 run");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
