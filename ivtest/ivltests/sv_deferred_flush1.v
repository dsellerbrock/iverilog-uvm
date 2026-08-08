// IEEE 1800-2017 16.4 restricts each deferred action arm to one
// subroutine call (or null). A statement block is illegal, even if it
// contains only calls. This is intentionally a compile-error test.
module t;
  initial begin
    assert #0 (0) else begin
      $display("one call still does not make a statement block legal");
    end
  end
endmodule
