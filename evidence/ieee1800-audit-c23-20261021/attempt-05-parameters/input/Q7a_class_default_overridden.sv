class C;
endclass

module M #(type T = C, T p = 4) ();
    initial $display("%0d", p);
endmodule

module top;
    M #(.T(int)) u();
endmodule
