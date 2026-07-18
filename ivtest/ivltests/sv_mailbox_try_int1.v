module test;
  mailbox #(int) mbx;
  int v;
  bit ok;

  initial begin
    mbx = new();

    ok = mbx.try_put(7);
    if (!ok) begin
      $display("FAILED: try_put");
      $finish;
    end

    ok = mbx.try_peek(v);
    if (!ok || v !== 7) begin
      $display("FAILED: try_peek ok=%0d v=%0d", ok, v);
      $finish;
    end

    v = -1;
    ok = mbx.try_get(v);
    if (!ok || v !== 7) begin
      $display("FAILED: try_get ok=%0d v=%0d", ok, v);
      $finish;
    end

    v = -1;
    ok = mbx.try_get(v);
    if (ok || v !== 0) begin
      $display("FAILED: empty try_get ok=%0d v=%0d", ok, v);
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule
