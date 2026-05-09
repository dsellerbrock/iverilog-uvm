// S5 step 5: `guard throughout (a ##5 b)` - guard must hold throughout.
module top;
    bit clk = 0;
    bit guard, req, ack;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) guard throughout (req ##5 ack))
        else begin err++; $display(":assert: False  // throughout fired t=%0t", $time); end

    initial begin
        guard <= 0; req <= 0; ack <= 0;
        @(posedge clk);
        guard <= 1;                  // guard high from now
        req <= 1;
        @(posedge clk); req <= 0;    // sample c2: req=1, guard=1 (start of attempt)
        @(posedge clk);              // c3
        @(posedge clk); @(posedge clk); @(posedge clk);
        ack <= 1;
        @(posedge clk);              // c7: deadline; need guard at every cycle in [c2..c7] AND ack at c7
        ack <= 0; guard <= 0;
        @(posedge clk); @(posedge clk);
        if (err == 0) $display("PASS: throughout with steady guard");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
