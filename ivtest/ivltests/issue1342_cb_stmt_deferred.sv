module top;
  initial begin
    $asserton(0, top);
    assert #0 (1'b1) $display("DEFERRED_ACTION");
    #1;
    $finish;
  end
endmodule
