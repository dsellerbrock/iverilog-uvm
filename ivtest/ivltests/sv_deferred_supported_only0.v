module t;
  task automatic unsupported_context;
    assert #0 (0) else $display("TASK");
  endtask

  int x = 7;
  initial begin
    assert final (0) else $display("FINAL");
    assert #0 (0) else $display("x=%0d", x);
    cover #0 (1);
    unsupported_context();
    assert #0 (0) else $display("SUPPORTED");
    #1 $display("PASSED");
  end

  final assert #0 (0) else $display("FINAL_PROC");
endmodule
