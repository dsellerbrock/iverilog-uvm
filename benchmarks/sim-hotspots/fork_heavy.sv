`timescale 1ns/1ps
module top;
  integer leaves;
  task automatic fork_tree(input integer depth);
    if (depth == 0) begin
      #1 leaves = leaves + 1;
    end else begin
      fork
        fork_tree(depth - 1);
        fork_tree(depth - 1);
      join
    end
  endtask
  initial begin
    leaves = 0;
    fork_tree(13);
    $display("forked_leaves=%0d", leaves);
    $finish;
  end
endmodule
