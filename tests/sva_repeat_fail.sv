// S6 step 4: b[*3] SHOULD FIRE when b held only 2 cycles before dropping.
module top;
    bit clk = 0;
    bit b;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) b[*3])
        else begin err++; $display(":assert: True  // b[*3] caught t=%0t", $time); end

    initial begin
        b <= 0;
        @(posedge clk);
        b <= 1;
        @(posedge clk); @(posedge clk);    // 2 cycles of b=1
        b <= 0;                            // b drops on cycle 3 → attempt at cycle 1 fails at cycle 3
        @(posedge clk);                    // attempt deadline = T+2 = cycle 3; check started_dly[2] && !match
        @(posedge clk); @(posedge clk);
        if (err >= 1) $display("PASS: b[*3] caught %0d violation", err);
        else $display(":assert: False  // expected fire, got %0d", err);
        $finish;
    end
endmodule
