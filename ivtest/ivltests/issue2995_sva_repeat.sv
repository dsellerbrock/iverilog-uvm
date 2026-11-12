module issue2995_sva_repeat;
  bit clk = 0, a = 0, b = 1;
  integer plus_hits = 0, plus_range_hits = 0;
  integer star_hits = 0, star_range_hits = 0;
  integer spaced_plus_hits = 0, spaced_star_hits = 0;
  integer group_hits = 0, group_range_hits = 0;
  always #5 clk = ~clk;

  cover property (@(posedge clk) a[+] ##1 b) plus_hits++;
  cover property (@(posedge clk) a[*1:$] ##1 b) plus_range_hits++;
  cover property (@(posedge clk) a[*] ##1 b) star_hits++;
  cover property (@(posedge clk) a[*0:$] ##1 b) star_range_hits++;
  cover property (@(posedge clk) (a) [ + ] ##1 b) spaced_plus_hits++;
  cover property (@(posedge clk) (a) [ * ] ##1 b) spaced_star_hits++;
  cover property (@(posedge clk) (a ##1 a)[+] ##1 b) group_hits++;
  cover property (@(posedge clk) (a ##1 a)[*1:$] ##1 b) group_range_hits++;

  initial begin
    #10 a = 1;
    #30 a = 0;
    #20;
    if (plus_hits == 0 || star_hits == 0 || star_hits <= plus_hits ||
        plus_hits != plus_range_hits || plus_hits != spaced_plus_hits ||
        star_hits != star_range_hits || star_hits != spaced_star_hits ||
        group_hits == 0 || group_hits != group_range_hits)
      $fatal(1, "repetition mismatch: plus %0d/%0d/%0d star %0d/%0d/%0d",
             plus_hits, plus_range_hits, spaced_plus_hits,
             star_hits, star_range_hits, spaced_star_hits);
    $display("PASS");
    $finish;
  end
endmodule
