module t;
  initial begin
    // Omitted failure action requests the standard default $error report.
    assert final (0);
    assert final (0) else ;
    assert final (1);
    #1 $display("PASSED");
  end
endmodule
