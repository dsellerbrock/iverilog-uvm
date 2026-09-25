module otp_mask_tree_three;
 wire [2:0] tree;
 assign tree[0] = 1'b0;
 assign tree[1] = tree[0];
 assign tree[2] = tree[1] | 1'b1;
 initial begin
   #1;
   $display("tree=%b root=%b leaf=%b", tree, tree[0], tree[2]);
   if (tree !== 3'b100) $fatal(1, "legal disjoint tree wrong");
   $finish;
 end
endmodule
