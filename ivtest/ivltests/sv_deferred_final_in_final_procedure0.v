module deferred_final_in_final_procedure;
  int value = 0;

  final begin : source
    value = 40;
    $display("FINAL_ENTER %0d", value);
    assert final (0)
      else $display("POST_FINAL %m VALUE=%0d", value);
    value = 41;
    $display("FINAL_EXIT %0d", value);
  end
endmodule
