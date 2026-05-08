// S4: A ##N B should HOLD (no fire).  q = d through 3-stage pipe.
module top;
    bit clk = 0;
    bit d, q1, q2, q3;
    int err = 0;
    always #5 clk = ~clk;
    always_ff @(posedge clk) begin q1 <= d; q2 <= q1; q3 <= q2; end

    // d at cycle T -> q3 at cycle T+3.
    assert property (@(posedge clk) d ##3 q3)
        else begin err++; $display(":assert: False  // ##3 fired t=%0t d-3=?  q3=%0d", $time, q3); end

    initial begin
        d <= 0;
        @(posedge clk);                        // t=5  q1<=0
        d <= 1; @(posedge clk);                // t=15 q1<=1, q2<=0
        d <= 0; @(posedge clk);                // t=25 q1<=0, q2<=1, q3<=0
        d <= 0; @(posedge clk);                // t=35: ant_T-3=d_T=5=1?, no — d at t=5 was 0, so dly[2]=0, no fire.
        d <= 0; @(posedge clk);                // t=45 dly[2]=d_at_t=15=1, q3=1 (from q2 at t=35 which was 1)?
        @(posedge clk);
        @(posedge clk);
        if (err == 0) $display("PASS: ##3 holds along pipeline");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
