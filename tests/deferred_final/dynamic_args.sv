module deferred_final_dynamic_args;
  int x = 7;
  initial assert final (0) else $display("x=%0d", x);
endmodule
