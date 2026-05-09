// S5 step 3: ##[1:3] should FIRE — req at T but no gnt in [T+1, T+3].
module top;
    bit clk = 0;
    bit req, gnt;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) req ##[1:3] gnt)
        else begin err++; $display(":assert: True  // ##[1:3] caught miss t=%0t", $time); end

    initial begin
        req <= 0; gnt <= 0;
        @(posedge clk);
        req <= 1;                            // req at t=5 sample
        @(posedge clk); req <= 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);                      // deadline T+3 hit, no gnt → fire
        @(posedge clk);
        @(posedge clk);
        if (err >= 1) $display("PASS: ##[1:3] caught %0d misses", err);
        else $display(":assert: False  // expected fire, got %0d", err);
        $finish;
    end
endmodule
