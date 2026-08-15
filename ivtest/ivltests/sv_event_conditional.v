module test;
  logic clk = 0;
  logic alt = 0;
  logic en = 0;
  logic alt_en = 0;
  logic nba_source = 1;
  logic nba_target = 0;
  logic [1:0] nba_vector = 0;
  integer nba_index = 0;
  integer always_hits = 0;
  integer one_shot_hits = 0;
  integer or_hits = 0;
  integer detached_hits = 0;

  always @(posedge clk iff en)
    always_hits += 1;

  initial begin
    @(posedge clk iff en);
    one_shot_hits += 1;
  end

  initial
    nba_target <= @(posedge clk iff en) nba_source;

  initial
    nba_vector[nba_index] <= @(posedge clk iff en) 1'b1;

  initial begin
    fork
      begin #14 detached_hits += 1; end
    join_none
    @(posedge clk iff 1'b0 or posedge alt iff alt_en);
    or_hits += 1;
  end

  initial begin
    #1 clk = 1; #1 clk = 0;
    en = 1;
    nba_source = 0;
    nba_index = 1;
    #1 clk = 1; #1 clk = 0;
    en = 1'bx;
    #1 clk = 1; #1 clk = 0;
    en = 1'bz;
    #1 clk = 1; #1 clk = 0;
    en = 1;
    #1 clk = 1; #1 clk = 0;
    #1 alt = 1; #1 alt = 0;
    alt_en = 1;
    #1 alt = 1; #1 alt = 0;
    #1;

    if (always_hits != 2 || one_shot_hits != 1 || or_hits != 1 ||
        detached_hits != 1 || nba_target !== 1 || nba_vector !== 2'b01) begin
      $display("FAILED always=%0d one_shot=%0d or=%0d detached=%0d nba=%b/%b",
               always_hits, one_shot_hits, or_hits, detached_hits,
               nba_target, nba_vector);
      $finish;
    end
    $display("PASSED");
  end
endmodule
