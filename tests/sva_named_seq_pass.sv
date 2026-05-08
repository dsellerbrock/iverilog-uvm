// S3: real named sequence — should HOLD.
module top;
    bit clk = 0;
    bit d, q;
    int err = 0;
    always #5 clk = ~clk;
    always_ff @(posedge clk) q <= d;

    sequence q_tracks_d;
        @(posedge clk) q == $past(d);
    endsequence

    assert property (q_tracks_d)
        else begin err++; $display(":assert: False  // named sequence fired t=%0t", $time); end

    initial begin
        d <= 0;
        @(posedge clk);
        d <= 1; @(posedge clk);
        d <= 0; @(posedge clk);
        d <= 1; @(posedge clk);
        if (err == 0) $display("PASS: named sequence q_tracks_d holds");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
