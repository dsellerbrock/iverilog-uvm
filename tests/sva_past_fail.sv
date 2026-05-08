// S2: $past — SHOULD FIRE.  Property is wrong: claims `d == $past(d)`
// always, which is false when d toggles.
module top;
    bit clk = 0;
    bit d;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) d == $past(d))
        else begin err++; $display(":assert: True  // d=%0d $past(d) differs at t=%0t", d, $time); end

    initial begin
        d <= 0;
        @(posedge clk);
        d <= 1; @(posedge clk);    // $past(d)=0, d=1 → fire
        d <= 0; @(posedge clk);    // $past(d)=1, d=0 → fire
        d <= 1; @(posedge clk);    // fire
        if (err >= 2) $display("PASS: $past mismatch caught %0d times", err);
        else $display(":assert: False  // expected fires, only %0d", err);
        $finish;
    end
endmodule
