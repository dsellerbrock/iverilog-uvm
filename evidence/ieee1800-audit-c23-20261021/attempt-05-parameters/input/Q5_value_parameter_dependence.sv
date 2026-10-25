module d #(parameter p = 1, parameter [p:0] p2 = 4);
endmodule

module top;
    d u0();
    d #(.p(3)) u1();
    initial $display("%0d %0d %0d %0d", $bits(u0.p2), u0.p2, $bits(u1.p2), u1.p2);
endmodule
