// S3: named property — SHOULD FIRE.
module top;
    bit clk = 0;
    bit a, b;
    int err = 0;
    always #5 clk = ~clk;

    property bad_implication;
        @(posedge clk) a |=> b;
    endproperty

    assert property (bad_implication)
        else begin err++; $display(":assert: True  // caught at t=%0t", $time); end

    initial begin
        a <= 0; b <= 0;
        @(posedge clk);
        a <= 1; @(posedge clk);  // ant=1
        // b stays 0 -- next cycle |=> should fire
        @(posedge clk);
        @(posedge clk);
        if (err >= 1) $display("PASS: named fail fired %0d times", err);
        else $display(":assert: False  // expected fire, got %0d", err);
        $finish;
    end
endmodule
