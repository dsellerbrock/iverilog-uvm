module top;
  integer boundary_phase;
  bit boundary_waiting = 0;
  event boundary_flush;

  task hit;
    observed_hit: cover #0 (1);
  endtask

  task miss;
    observed_miss: cover #0 (0);
  endtask

  initial begin
    boundary_phase = 0;
    while (boundary_phase < 2) begin
      observed_boundary: cover #0 (boundary_phase == 1);
      boundary_phase = boundary_phase + 1;
      if (boundary_phase == 1) begin
        boundary_waiting = 1;
        @(boundary_flush);
      end
    end

    hit();
    hit();
    miss();

    final_hit: cover final (1);
    final_miss: cover final (0);

    #1 $display("PASS: issue443 deferred cover scenarios completed");
    $display("PASSED");
  end

  initial begin
    wait (boundary_waiting);
    -> boundary_flush;
  end
endmodule
