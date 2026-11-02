`timescale 1ns/1ps

module issue1569_leaf(input wire a);
    always @(a) $display("LOAD %0t %b", $time, a);
endmodule

module issue1569_parent(output logic y);
    issue1569_leaf u2(.a(y));

    initial begin
        y = 1'b0;
        #10 y = 1'b1;
    end
endmodule

module tb;
    wire y;
    issue1569_parent u1(.y(y));

    initial begin
        $sdf_annotate("ivltests/issue1569_down_hierarchy_interconnect.sdf", tb);
        $monitor("t=%0t y=%b a=%b", $time, y, u1.u2.a);
        #20 $finish;
    end
endmodule
