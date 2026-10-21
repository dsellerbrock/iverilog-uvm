module child(inout supply1 w);
    initial begin #1; $display("K4 %b %v", w, w); end
endmodule
module top;
    wire ext;
    assign ext = 1'b0;
    child dut(ext);
endmodule
