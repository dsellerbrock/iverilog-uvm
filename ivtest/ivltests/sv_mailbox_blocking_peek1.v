module test;
  mailbox #(int) mbx;
  int peeked;
  int got;

  initial mbx = new();

  initial fork
    begin
      mbx.peek(peeked);
      if (peeked !== 42) begin
        $display("FAIL: peeked=%0d", peeked);
        $finish;
      end
      mbx.get(got);
      if (got !== 42) begin
        $display("FAIL: got=%0d", got);
        $finish;
      end
      $display("PASS");
      $finish;
    end
    begin
      #1;
      mbx.put(42);
    end
  join
endmodule
