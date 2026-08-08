module t;
  logic go = 1'b0;

  // Straight-line re-execution is not a flush point. Every execution of
  // the same source statement creates an independent pending report.
  initial begin
    repeat (3)
      assert #0 (0) else $display("FIFO");
    assert #0 (0) else $display("A");
    assert #0 (0) else $display("B");
    assert #0 (0) else $display("C");
  end

  // Resuming after an event control flushes all older pending reports for
  // this logical process. The report queued after the resume is retained.
  initial begin
    assert #0 (0) else $display("FLUSHED");
    @(posedge go);
    assert #0 (0) else $display("KEPT");
  end

  initial begin
    #0 go = 1'b1;
    #1 $display("PASSED");
  end
endmodule
