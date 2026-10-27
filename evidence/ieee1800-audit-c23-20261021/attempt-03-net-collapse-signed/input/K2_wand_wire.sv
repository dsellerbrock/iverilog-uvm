module child(inout wand w);
    assign w = 1'b1;
    initial begin #1; $display("K2 %b %v", w, w); end
endmodule
module top;
    wire ext;
    assign ext = 1'b0;
    child dut(ext);
endmodule
