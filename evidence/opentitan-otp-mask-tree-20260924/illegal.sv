module otp_mask_tree_illegal;
 logic [2:0] tree;
 assign tree[0] = 1'b0;
 assign tree[0] = 1'b1; // illegal: overlapping continuous drivers on a variable bit
endmodule
