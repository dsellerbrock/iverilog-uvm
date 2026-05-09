// S5 step 4: intersect should FIRE when req at T but no gnt0 && gnt1 at T+5.
module top;
    bit clk = 0;
    bit req, gnt0, gnt1;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) (req ##5 gnt0) intersect (req ##5 gnt1))
        else begin err++; $display(":assert: True  // intersect caught t=%0t", $time); end

    initial begin
        req <= 0; gnt0 <= 0; gnt1 <= 0;
        @(posedge clk);
        req <= 1;
        @(posedge clk); req <= 0;
        @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk);
        gnt0 <= 1;                                 // gnt0 only, gnt1 stays 0
        @(posedge clk);                            // c7: dly[4]==1, gnt0=1, gnt1=0 → fire
        gnt0 <= 0;
        @(posedge clk); @(posedge clk);
        if (err >= 1) $display("PASS: intersect caught %0d miss", err);
        else $display(":assert: False  // expected fire, got %0d", err);
        $finish;
    end
endmodule
