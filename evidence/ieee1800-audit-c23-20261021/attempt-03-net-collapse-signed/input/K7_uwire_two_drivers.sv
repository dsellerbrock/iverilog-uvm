module child(inout uwire w);
    assign w = 1'b1;
endmodule
module top;
    wire ext;
    assign ext = 1'b0;
    child dut(ext);
endmodule
