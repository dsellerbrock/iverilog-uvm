// S1 validation: |=> should FAIL; assertion MUST fire.
module top;
    bit clk = 0;
    bit a, b;
    int err_count = 0;
    always #5 clk = ~clk;

    assert property (@(posedge clk) a |=> b)
        else begin
            err_count++;
            $display(":assert: True  // |=> correctly caught violation at t=%0t", $time);
        end

    initial begin
        a <= 0; b <= 0;
        @(posedge clk);            // clock 1: ant <= 0
        a <= 1;
        @(posedge clk);            // clock 2: ant <= 1
        a <= 0;                    // b stays 0
        @(posedge clk);            // clock 3: ant_prev=1, b=0 → MUST FIRE
        @(posedge clk);
        if (err_count > 0)
            $display("PASS: |=> caught %0d violation(s)", err_count);
        else
            $display(":assert: False  // |=> failed to fire on violation");
        $finish;
    end
endmodule
