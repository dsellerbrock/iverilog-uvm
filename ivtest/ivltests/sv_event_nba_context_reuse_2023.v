module nba_context_reuse;
  bit trigger = 1;
  int hits[2];
  bit done;

  task automatic watch(input int id);
    bit local_enable = 1;
    if (id == 0) begin
      fork
        begin @(negedge (trigger & local_enable)); hits[id]++; end
        begin @(negedge trigger); end
      join_any
      disable fork;
    end else begin
      @(negedge (trigger & local_enable));
      hits[id]++;
    end
  endtask

  initial begin
    #1;
    trigger <= 0;
    watch(0);
    watch(1);
  end

  initial begin
    #2;
    if (hits[0] != 0 || hits[1] != 0)
      $fatal(1, "stale pending context delivery hits=%p", hits);
    $display("PASSED");
    done = 1;
  end
  initial #20 if (!done) $fatal(1, "TIMEOUT");
endmodule
