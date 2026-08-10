module deferred_final_error_args;
  initial assert final (0) else $error("MUST EVENTUALLY RUN");
endmodule
