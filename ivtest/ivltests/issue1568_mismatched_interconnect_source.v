`timescale 1ns/1ps

module issue1568_source(output logic y);
    initial begin
        y = 1'b0;
        #10 y = 1'b1;
    end
endmodule

module issue1568_load(input logic a);
    always @(a)
        if (a === 1'b1) $display("LOAD %0t %b", $time, a);
endmodule

module tb;
    wire n, other;
    issue1568_source u1(.y(n));
    issue1568_source u4(.y(other));
    issue1568_load u2(.a(n));

    initial begin
        $sdf_annotate("ivltests/issue1568_mismatched_interconnect_source.sdf", tb);
        #20 $finish;
    end
endmodule
