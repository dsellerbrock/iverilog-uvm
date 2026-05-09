// S5 step 5: `guard throughout` SHOULD FIRE — guard drops mid-span.
module top;
    bit clk = 0;
    bit guard, req, ack;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) guard throughout (req ##5 ack))
        else begin err++; $display(":assert: True  // throughout caught t=%0t", $time); end

    initial begin
        guard <= 0; req <= 0; ack <= 0;
        @(posedge clk);
        guard <= 1; req <= 1;
        @(posedge clk); req <= 0;
        @(posedge clk);
        @(posedge clk); guard <= 0;            // guard drops mid-span
        @(posedge clk); guard <= 1;
        @(posedge clk);
        ack <= 1;
        @(posedge clk);                        // deadline: guard wasn't held the whole time → fire
        ack <= 0; guard <= 0;
        @(posedge clk); @(posedge clk);
        if (err >= 1) $display("PASS: throughout caught %0d violation", err);
        else $display(":assert: False  // expected fire, got %0d", err);
        $finish;
    end
endmodule
