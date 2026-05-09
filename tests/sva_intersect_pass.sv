// S5 step 4: intersect((req ##5 gnt0), (req ##[1:9] gnt1)) - should HOLD
// when req at T leads to gnt0 && gnt1 both at T+5.
module top;
    bit clk = 0;
    bit req, gnt0, gnt1;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) (req ##5 gnt0) intersect (req ##5 gnt1))
        else begin err++; $display(":assert: False  // intersect fired t=%0t", $time); end

    initial begin
        req <= 0; gnt0 <= 0; gnt1 <= 0;
        @(posedge clk);                            // c1
        req <= 1;                                  // req at c2's preponed
        @(posedge clk);                            // c2: req sampled=1, dly[0]<=1
        req <= 0;
        @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk);
        gnt0 <= 1; gnt1 <= 1;                      // before c7
        @(posedge clk);                            // c7: dly[4]==1 (req held 5 cycles ago), gnt0&&gnt1=1, no fire
        gnt0 <= 0; gnt1 <= 0;
        @(posedge clk); @(posedge clk);
        if (err == 0) $display("PASS: intersect holds with shared 5-cycle delay");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
