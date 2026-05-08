// S3: named property with |=> — should HOLD.
module top;
    bit clk = 0;
    bit a, b;
    int err = 0;
    always #5 clk = ~clk;

    property a_then_b;
        @(posedge clk) a |=> b;
    endproperty

    assert property (a_then_b)
        else begin err++; $display(":assert: False  // a |=> b fired t=%0t", $time); end

    initial begin
        a <= 0; b <= 0;
        @(posedge clk);
        a <= 1; @(posedge clk);
        a <= 0; b <= 1;
        @(posedge clk);
        @(posedge clk);
        if (err == 0) $display("PASS: named property a_then_b holds");
        else $display(":assert: False  // %0d errors", err);
        $finish;
    end
endmodule
