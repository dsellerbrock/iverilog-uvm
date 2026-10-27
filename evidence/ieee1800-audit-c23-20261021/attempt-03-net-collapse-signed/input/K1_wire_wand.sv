module child(inout wire w);
    assign w = 1'b1;
    initial begin #1; $display("K1 %b %v", w, w); end
endmodule
module top;
    wand ext;
    assign ext = 1'b0;
    child dut(ext);
endmodule
