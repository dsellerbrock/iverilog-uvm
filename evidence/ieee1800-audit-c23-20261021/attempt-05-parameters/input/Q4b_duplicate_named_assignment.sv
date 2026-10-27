module pm #(parameter P = 5, Q = 6);
endmodule

module top;
    pm #(.P(1), .P(2)) u();
endmodule
