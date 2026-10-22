module c1(output logic o, input logic i);
    assign o = ~i;
endmodule

module top;
    logic O[4], I[4] = '{1, 0, 1, 1};
    c1 u[4](O, I);
    initial begin
        #1 $display("%0d %0d %0d %0d", O[0], O[1], O[2], O[3]);
    end
endmodule
