// An itemless clocking block is still a clocking synchronization event.
// Pin the event-region boundary for direct, hierarchical, default-cycle-delay,
// and global/static references.  The two-stage NBA cascade is complete before
// a process waiting on the clocking event resumes.
`timescale 1ns/1ps

interface itemless_static_if(input logic clk);
  clocking cb @(posedge clk);
  endclocking
endinterface

module sv_clocking_itemless_static_event;
  logic clk = 1'b0;
  int nba_stage1 = 0;
  int nba_stage2 = 0;
  logic [7:0] sampled_data = 8'h11;
  int direct_hits = 0;
  int hier_hits = 0;
  int default_hits = 0;
  int global_hits = 0;
  int raw_hits = 0;
  int populated_hits = 0;
  int failures = 0;

  itemless_static_if bus(clk);

  always #5 clk = ~clk;

  // stage1 changes in NBA; that change schedules a second NBA update.  A raw
  // @(posedge clk) waiter sees neither update, while a clocking-event waiter
  // resumes only after the complete NBA cascade.
  always @(posedge clk)
    nba_stage1 <= nba_stage1 + 1;

  always @(nba_stage1)
    nba_stage2 <= nba_stage1;

  // Keep the declared clocking input stable for half a cycle before each
  // posedge: the three #1step samples must therefore be 11, 22, and 33.
  always @(negedge clk)
    sampled_data <= sampled_data + 8'h11;

  clocking direct_cb @(posedge clk);
  endclocking

  clocking populated_cb @(posedge clk);
    input sampled_data;
  endclocking

  default clocking default_cb @(posedge clk);
  endclocking

  global clocking global_cb @(posedge clk);
  endclocking

  task automatic check_event(input string path, input int hits,
                             input int want);
    if ($time != (want * 10 - 5) * 1ns || nba_stage1 != want ||
        nba_stage2 != want) begin
      failures++;
      $display("FAILED %s hit=%0d time=%0t stage1=%0d stage2=%0d want=%0d",
               path, hits, $time, nba_stage1, nba_stage2, want);
    end
  endtask

  initial begin
    repeat (3) begin
      @(posedge clk);
      raw_hits++;
      // Deliberate control: a raw-edge waiter runs in Active and therefore
      // still sees the values from before this edge's NBA cascade.
      if ($time != (raw_hits * 10 - 5) * 1ns ||
          nba_stage1 != raw_hits - 1 || nba_stage2 != raw_hits - 1) begin
        failures++;
        $display("FAILED raw control hit=%0d time=%0t stage1=%0d stage2=%0d",
                 raw_hits, $time, nba_stage1, nba_stage2);
      end
    end
  end

  initial begin
    repeat (3) begin
      @(populated_cb);
      populated_hits++;
      if ($time != (populated_hits * 10 - 5) * 1ns ||
          nba_stage1 != populated_hits || nba_stage2 != populated_hits ||
          populated_cb.sampled_data != populated_hits * 8'h11) begin
        failures++;
        $display("FAILED populated control hit=%0d time=%0t stage1=%0d stage2=%0d sample=%h",
                 populated_hits, $time, nba_stage1, nba_stage2,
                 populated_cb.sampled_data);
      end
    end
  end

  initial begin
    repeat (3) begin
      @(direct_cb);
      direct_hits++;
      check_event("direct", direct_hits, direct_hits);
    end
  end

  initial begin
    repeat (3) begin
      @(bus.cb);
      hier_hits++;
      check_event("hierarchical", hier_hits, hier_hits);
    end
  end

  initial begin
    repeat (3) begin
      ##1;
      default_hits++;
      check_event("default ##1", default_hits, default_hits);
    end
  end

  initial begin
    repeat (3) begin
      @($global_clock);
      global_hits++;
      check_event("$global_clock", global_hits, global_hits);
    end
  end

  initial begin
    #31;
    if (raw_hits != 3 || populated_hits != 3 || direct_hits != 3 ||
        hier_hits != 3 ||
        default_hits != 3 ||
        global_hits != 3) begin
      failures++;
      $display("FAILED waiter counts raw=%0d populated=%0d direct=%0d hierarchical=%0d default=%0d global=%0d",
               raw_hits, populated_hits, direct_hits, hier_hits, default_hits,
               global_hits);
    end
    if (failures != 0)
      $fatal(1, "%0d itemless static clocking-event checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
