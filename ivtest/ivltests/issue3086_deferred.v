module issue3086_deferred;
  function void check(bit value);
    assert final (value) $display("PASS %0d", value);
    else $display("FAIL %0d", value);
  endfunction

  function void failure_only(bit value);
    assert final (value) else $display("FAILURE_ONLY");
  endfunction

  event resume_event;
  initial begin
    check(0); check(1); check(0);
    failure_only(0); failure_only(1);
    #1 $display("DONE");
  end

  initial begin
    check(0);
    check(0);
    @resume_event;
    check(1);
  end
  initial begin
    #0 -> resume_event;
  end
endmodule
