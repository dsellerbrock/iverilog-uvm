// S4: A ##N B SHOULD FIRE.  Property is wrong: claims `d ##2 d_inverted`.
module top;
    bit clk = 0;
    bit d;
    int err = 0;
    always #5 clk = ~clk;

    // After 2 cycles, d will NOT be inverted (it's just held), so this
    // will fire whenever d was 1 two cycles ago.
    assert property (@(posedge clk) d ##2 !d)
        else begin err++; $display(":assert: True  // ##2 caught violation t=%0t", $time); end

    initial begin
        d <= 1;                                // d = 1 from t=0 onwards
        @(posedge clk);                        // t=5  cap d=1
        @(posedge clk);                        // t=15 cap d=1
        @(posedge clk);                        // t=25 dly[1]=d_at_t=5=1, !d=!1=0 → FIRE
        @(posedge clk);                        // t=35 dly[1]=d_at_t=15=1 → FIRE
        @(posedge clk);                        // t=45 → FIRE
        if (err >= 2) $display("PASS: ##2 caught %0d violations", err);
        else $display(":assert: False  // expected fires, got %0d", err);
        $finish;
    end
endmodule
