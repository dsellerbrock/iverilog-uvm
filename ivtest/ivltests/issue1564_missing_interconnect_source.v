`timescale 1ns/1ps

module source_port(output logic y);
    initial begin
        y = 1'b0;
        #10 y = 1'b1;
    end
endmodule

module load_port(input logic a);
    always @(a)
        if (a === 1'b1) $display("LOAD %0t %b", $time, a);
endmodule

module tb;
    wire n;
    source_port u1(.y(n));
    load_port u2(.a(n));

    initial begin
        $sdf_annotate("ivltests/issue1564_missing_interconnect_source.sdf", tb);
        #20 $finish;
    end
endmodule
