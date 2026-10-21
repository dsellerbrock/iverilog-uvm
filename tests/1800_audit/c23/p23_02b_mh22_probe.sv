module mh22(input wire integer p_a, .p_b(s_b), p_c);
 logic [5:0] s_b;
 initial $display("MH22 %0d", $bits(p_a));
endmodule
