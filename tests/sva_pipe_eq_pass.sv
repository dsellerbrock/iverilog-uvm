// S1 validation: |=> SHOULD HOLD; assertion should NOT fire.
// Use NBA-driven signals to avoid races with the synthesized check.
module top;
    bit clk = 0;
    bit a, b;
    int err_count = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) a |=> b)
        else begin
            err_count++;
            $display(":assert: False  // |=> incorrectly fired at t=%0t (a=%0d b=%0d)", $time, a, b);
        end

    initial begin
        a <= 0; b <= 0;
        @(posedge clk);            // clock 1: ant <= 0
        a <= 1;                    // captured at clock 2's preponed
        @(posedge clk);            // clock 2: ant <= 1; check ant_prev=0, no fire
        a <= 0; b <= 1;            // captured at clock 3's preponed
        @(posedge clk);            // clock 3: check ant_prev=1, b=1, no fire
        @(posedge clk);            // clock 4: check ant_prev=0, no fire
        if (err_count == 0)
            $display("PASS: |=> held correctly");
        else
            $display(":assert: False  // had %0d unexpected errors", err_count);
        $finish;
    end
endmodule
