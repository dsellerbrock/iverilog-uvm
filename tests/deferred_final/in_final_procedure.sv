module deferred_final_in_final_procedure;
  final assert final (0) else $display("MUST EVENTUALLY RUN");
endmodule
