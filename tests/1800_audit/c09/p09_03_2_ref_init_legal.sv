module top;
  int g = 7, got;
  task automatic t(ref int x);
    fork automatic int k = x; got = k; join_none
  endtask
  initial begin
    t(g);
    #1 $display("%s 9.3.2.ref_arg_in_fork_block_item_init got=%0d", got == 7 ? "PASS" : "FAIL", got);
  end
endmodule
