// S5 step 5: SEQ_AND with same-end-time CONCATs.
module top;
    bit clk = 0;
    bit req, gnt0, gnt1;
    int err = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) (req ##5 gnt0) and (req ##5 gnt1))
        else begin err++; $display(":assert: False  // and fired t=%0t", $time); end

    initial begin
        req <= 0; gnt0 <= 0; gnt1 <= 0;
        @(posedge clk);
        req <= 1;
        @(posedge clk); req <= 0;
        @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk);
        gnt0 <= 1; gnt1 <= 1;
        @(posedge clk);
        gnt0 <= 0; gnt1 <= 0;
        @(posedge clk); @(posedge clk);
        if (err == 0) $display("PASS: and holds with shared 5-cycle delay");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
