module otp_mask_tree_scalar;
 wire root=1'b0;
 wire mid=root;
 wire leaf=mid | 1'b1;
 initial begin #1; if ({leaf,mid,root} !== 3'b100) $fatal(1,"scalar tree wrong"); $display("scalar=%b",{leaf,mid,root}); $finish; end
endmodule
