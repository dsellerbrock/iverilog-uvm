// G12: streaming LHS {>>{a,b,c,d}} = src
// Expected: a=AA b=BB c=CC d=DD (big-endian, MSB-first)
module g12_streaming_lhs_test;
  byte a, b, c, d;
  initial begin
    {>>{a, b, c, d}} = 32'hAABBCCDD;
    if (a === 8'hAA && b === 8'hBB && c === 8'hCC && d === 8'hDD) begin
      $display("PASS: a=%0h b=%0h c=%0h d=%0h", a, b, c, d);
    end else begin
      $display("FAIL: a=%0h b=%0h c=%0h d=%0h (expected AA BB CC DD)", a, b, c, d);
      $finish(1);
    end
  end
endmodule
