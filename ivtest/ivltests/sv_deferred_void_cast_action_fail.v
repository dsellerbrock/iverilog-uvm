module t;
  initial begin
    // A void-cast statement is not the direct subroutine-call action required
    // by 16.4. In particular, a system task cannot legally be void-cast.
    assert #0 (0) else void'($display("MUST NOT RUN"));
  end
endmodule
