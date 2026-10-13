module top;
    event e;
    integer seen = 0;

    always @(e) seen = seen + 1;

    initial begin
        #1 -> e; // Let the time-zero event-control process arm before triggering.
        #1;
        if (seen != 1) $fatal(1, "event waiter saw %0d triggers", seen);
        $display(":assert: (1 == 1)");
        $finish;
    end
endmodule
