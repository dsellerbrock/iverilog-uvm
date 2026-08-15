module deferred_observed_ref_action;
  int value = 7;

  task automatic report(ref int actual);
    $display("VALUE=%0d", actual);
  endtask

  initial assert #0 (0) else report(value);
endmodule
