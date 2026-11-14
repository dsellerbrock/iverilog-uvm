module issue3163_final_flush;
  event wake, wake_final_only;

  initial begin
    assert #0 (0) else $display("ERROR: observed report survived");
    assert final (0) else $display("ERROR: final report survived");
    @wake;
    assert final (0) else $display("final after resume");
    #1;
    assert final (0) else $display("ERROR: final-only report survived");
    @wake_final_only;
    #1 $display("done");
  end

  initial begin
    assert final (0) else $display("independent final");
    #0 -> wake;
    #1 #0 -> wake_final_only;
  end
endmodule
