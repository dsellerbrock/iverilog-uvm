module sv_block_scope_lifetimes;
  int total, done;
  int values[2] = '{3, 5};
  initial begin : outer
    int k;
    for (int i=0; i<2; i++) begin : local_block
      automatic int saved = i;
      foreach (values[j]) begin
        total += values[j] + saved;
      end
    end
    again: for(k=0; k<2; k++) labeled: begin
      total += k;
    end
    fork : workers
      begin #1; done += 1; end
      begin #2; done += 2; end
    join
    if(total != 19 || done != 3 || k != 2) $fatal(1,"scope/lifetime mismatch");
    $display("PASSED");
  end
endmodule
