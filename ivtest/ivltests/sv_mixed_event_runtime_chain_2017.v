class sv_mixed_event_runtime_chain_cfg;
  int idx;
endclass

module sv_mixed_event_runtime_chain;
  sv_mixed_event_runtime_chain_cfg cfg;

  task automatic exercise;
    logic [3:0] sr;
    int c0, c1, c2;

    sr = '0;
    cfg.idx = 0;
    c0 = 0; c1 = 0; c2 = 0;
    fork
      begin @(sr[cfg.idx]); c0++; end
      begin @(sr[cfg.idx]); c1++; end
      begin @(sr[cfg.idx]); c2++; end
    join_none
    #1 sr[0] = 1;
    #1 if (c0 != 1 || c1 != 1 || c2 != 1)
      $fatal(1, "ordinary chain wake counts=%0d,%0d,%0d", c0, c1, c2);
    cfg.idx = 1;
    #1 if (c0 != 1 || c1 != 1 || c2 != 1)
      $fatal(1, "stale mutation registration counts=%0d,%0d,%0d", c0, c1, c2);

    sr = '0;
    cfg.idx = 0;
    c0 = 0; c1 = 0; c2 = 0;
    sr[1] = 1;
    fork
      begin @(sr[cfg.idx]); c0++; end
      begin @(sr[cfg.idx]); c1++; end
      begin @(sr[cfg.idx]); c2++; end
    join_none
    #1 cfg.idx = 1;
    #1 if (c0 != 1 || c1 != 1 || c2 != 1)
      $fatal(1, "mutation chain wake counts=%0d,%0d,%0d", c0, c1, c2);
    sr[1] = 0;
    #1 if (c0 != 1 || c1 != 1 || c2 != 1)
      $fatal(1, "stale ordinary registration counts=%0d,%0d,%0d", c0, c1, c2);

    sr = '0;
    cfg.idx = 0;
    c0 = 0; c1 = 0; c2 = 0;
    fork : cancellable
      begin : w0 @(sr[cfg.idx]); c0++; end
      begin : w1 @(sr[cfg.idx]); c1++; end
      begin : w2 @(sr[cfg.idx]); c2++; end
    join_none
    #1 disable cancellable.w1;
    sr[0] = 1;
    #1 if (c0 != 1 || c1 != 0 || c2 != 1)
      $fatal(1, "disable middle counts=%0d,%0d,%0d", c0, c1, c2);

    sr = '0;
    cfg.idx = 0;
    c0 = 0; c1 = 0; c2 = 0;
    fork
      begin @(sr[cfg.idx]); c0++; end
      begin @(sr[cfg.idx]); c1++; end
      begin @(sr[cfg.idx]); c2++; end
    join_none
    #1 begin
      cfg.idx = 1;
      sr[1] = 1;
    end
    #1 if (c0 != 1 || c1 != 1 || c2 != 1)
      $fatal(1, "simultaneous counts=%0d,%0d,%0d", c0, c1, c2);
  endtask

  initial begin
    cfg = new;
    exercise();
    $display("PASSED");
  end
endmodule
