// S6 step 5: $past(x, N>1) - should HOLD when x N cycles ago equals current expectation.
module top;
    bit clk = 0;
    bit d, q1, q2, q3;
    int err = 0;
    always #5 clk = ~clk;
    always_ff @(posedge clk) begin q1 <= d; q2 <= q1; q3 <= q2; end

    // q3 = $past(d, 3) is the property: q3 should equal d from 3 cycles ago.
    assert property (@(posedge clk) q3 == $past(d, 3))
        else begin err++; $display(":assert: False  // $past(d,3) mismatch t=%0t q3=%0d", $time, q3); end

    initial begin
        d <= 0;
        @(posedge clk);
        d <= 1; @(posedge clk);
        d <= 0; @(posedge clk);
        d <= 1; @(posedge clk);
        d <= 0; @(posedge clk);
        @(posedge clk); @(posedge clk);
        if (err == 0) $display("PASS: $past(d,3) tracks q3");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
