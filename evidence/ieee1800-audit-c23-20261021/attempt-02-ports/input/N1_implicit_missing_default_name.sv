module child(input logic [7:0] d = 8'h5A, output logic [7:0] q);
    assign q = d;
endmodule

module top;
    logic [7:0] q;
    child c(.d, .q);
endmodule
