// Issue #3086: IEEE 1800-2023 16.4.1/16.4.2. Each execution of a final
// deferred assertion places a report on the process's deferred assertion
// report queue, and only a flush point removes one. No flush point occurs
// between these three calls, so all three reports mature, in order.
module t;
  function void chk(bit v);
    assert final (v) $display("PASS %0d", v); else $display("FAIL %0d", v);
  endfunction
  initial begin chk(0); chk(1); chk(0); end
endmodule
