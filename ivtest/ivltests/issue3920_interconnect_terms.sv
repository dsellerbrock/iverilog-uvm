`timescale 1ns/1ps

module issue3920_load #(parameter WIDTH = 1)(input wire [WIDTH-1:0] a);
    wire [WIDTH-1:0] observed;
    assign observed = ~a;
endmodule

module issue3920_source(output logic y);
    initial begin
        y = 0;
        #10 y = 1;
        #10 y = 0;
    end
endmodule

module issue3920_sampled(input wire [1:0] drive, output logic [1:0] y);
    always_comb y = drive;
    issue3920_load #(2) delayed(y);
    issue3920_load #(2) sibling(y);
endmodule

module top;
    wire y;
    issue3920_source source(y);
    issue3920_load delayed(y);
    issue3920_load sibling(y);

    logic [1:0] drive = 2'b01;
    wire [1:0] sampled_y;
    issue3920_sampled sampled(drive, sampled_y);

    initial begin
        #4 $issue3920_probe;
        #1;
        $sdf_annotate("ivltests/issue3920_interconnect_terms.sdf", top);
        $issue3920_probe;
        #5 drive = 2'b10;
        $issue3920_probe;
        #1;
        $sdf_annotate("ivltests/issue3920_interconnect_terms.sdf", top);
        $issue3920_probe;
        #1.999 $issue3920_probe;
        #0.001 $issue3920_probe;
        #7 drive = 2'bzx;
        $issue3920_probe;
        #3 $issue3920_probe;
    end
endmodule
