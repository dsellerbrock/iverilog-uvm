// S5 step 3: bool `or` - should HOLD. (a || b) always true.
module top;
    bit clk = 0;
    bit a, b;
    int err = 0;
    always #5 clk = ~clk;
    assign b = ~a;  // always one of them holds

    assert property (@(posedge clk) a or b)
        else begin err++; $display(":assert: False  // or fired t=%0t a=%0d b=%0d", $time, a, b); end

    initial begin
        a <= 0;
        @(posedge clk);
        a <= 1; @(posedge clk);
        a <= 0; @(posedge clk);
        a <= 1; @(posedge clk);
        if (err == 0) $display("PASS: or holds when one of (a, b) true");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
