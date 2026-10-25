module my_mem;
    parameter addr_width = 16;
    localparam mem_size = 1 << addr_width;
    parameter data_width = 8;
    initial $display("%0d %0d %0d", addr_width, data_width, mem_size);
endmodule

module top;
    my_mem #(12, 16) m();
endmodule
