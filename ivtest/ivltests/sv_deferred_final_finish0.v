module t;
  initial begin
    assert final (0) else $display("FINISH_POSTPONED");
    // The current time slot, including Postponed, must drain before exit.
    $finish(0);
  end
endmodule
