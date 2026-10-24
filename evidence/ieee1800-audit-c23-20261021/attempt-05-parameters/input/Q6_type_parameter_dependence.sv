module t #(parameter type T = int, parameter T p3 = 7);
endmodule

module top;
    t u0();
    t #(.T(shortint)) u1();
    initial $display("%0d %0d %0d %0d", $bits(u0.p3), u0.p3, $bits(u1.p3), u1.p3);
endmodule
