module pm #(parameter P = 5, Q = 6);
    initial $display("%0d %0d", P, Q);
endmodule

module top;
    pm #(.P(), .Q(9)) u();
endmodule
