// S2: $past — should NOT fire.  At every clock after the first,
// `q` must equal `$past(d)` because q is registered from d.
module top;
    bit clk = 0;
    bit d, q;
    int err = 0;
    always #5 clk = ~clk;
    always_ff @(posedge clk) q <= d;

    assert property (@(posedge clk) q == $past(d))
        else begin err++; $display(":assert: False  // $past mismatch t=%0t d=%0d q=%0d $past(d)=last", $time, d, q); end

    initial begin
        d <= 0;
        @(posedge clk);            // clk=1: q<=0
        d <= 1; @(posedge clk);    // q<=1.  $past(d) = 1 (sampled at preponed of THIS clk after the prior assignment); q==1 ok
        d <= 0; @(posedge clk);
        d <= 1; @(posedge clk);
        d <= 0; @(posedge clk);
        if (err == 0) $display("PASS: $past(d) tracks q");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
