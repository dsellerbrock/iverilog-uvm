// S2: $changed — SHOULD FIRE on any change.
module top;
    bit clk = 0;
    bit d;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) !$changed(d))
        else begin err++; $display(":assert: True  // $changed(d) at t=%0t", $time); end

    initial begin
        d <= 0;
        @(posedge clk);
        d <= 1; @(posedge clk);    // changed: 0→1 fires
        d <= 1; @(posedge clk);    // no change: no fire
        d <= 0; @(posedge clk);    // changed: fires
        if (err >= 2) $display("PASS: $changed caught %0d transitions", err);
        else $display(":assert: False  // expected >=2 fires, got %0d", err);
        $finish;
    end
endmodule
