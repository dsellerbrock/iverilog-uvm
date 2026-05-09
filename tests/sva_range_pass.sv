// S5 step 3: ##[N:M] range delay - should HOLD.
// req at T -> gnt at some cycle in [T+1, T+3] holds.
module top;
    bit clk = 0;
    bit req, gnt;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) req ##[1:3] gnt)
        else begin err++; $display(":assert: False  // ##[1:3] fired t=%0t", $time); end

    initial begin
        req <= 0; gnt <= 0;
        @(posedge clk);
        @(posedge clk); req <= 1;            // t=15: req=1 at next cycle
        @(posedge clk); req <= 0; gnt <= 1;  // t=25: gnt=1 next cycle
        @(posedge clk); gnt <= 0;            // t=35
        @(posedge clk);
        @(posedge clk);
        if (err == 0) $display("PASS: ##[1:3] caught match in window");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
