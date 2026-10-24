module flop(input logic a, b, output logic c);
    parameter xyz = 0;
endmodule

module top;
    logic [7:0] in, in1;
    logic clk;
    wire [7:0] out1;
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : somename
            flop my_flop(in[i], in1[i], out1[i]);
            defparam somename[i+1].my_flop.xyz = i;
        end
    endgenerate
endmodule
