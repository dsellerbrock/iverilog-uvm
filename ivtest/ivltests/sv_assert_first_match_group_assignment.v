module sv_assert_first_match_group_assignment;
  bit clk=0;
  bit ma=0, mb=0, mc=0;
  bit na=0, nb=0, nc=0;
  bit ta=0, tb=0, tc=0;
  int md=0, td=0;
  int mid_hits=0, named_hits=0, inline_hits=0, tie_hits=0, sequence_local_hits=0;
  always #5 clk = ~clk;

  sequence named_seq;
    na ##[1:2] nb;
  endsequence

  sequence local_seq;
    int x;
    first_match(na, x=md) ##1 (nb && x==2);
  endsequence

  property p_midstep;
    int x;
    @(posedge clk)
      first_match(ma ##[1:2] (mb, x=md) ##1 mc) ##1 (x == 1);
  endproperty
  cover property (p_midstep) mid_hits++;

  cover property (@(posedge clk) first_match(named_seq) ##1 nc)
    named_hits++;
  cover property (@(posedge clk) first_match(na ##[1:2] nb) ##1 nc)
    inline_hits++;
  cover property (@(posedge clk) local_seq) sequence_local_hits++;

  property p_tied;
    int x;
    @(posedge clk)
      first_match(ta ##[1:2] tb ##[1:2] tc, x=td) ##1 (x == 7);
  endproperty
  cover property (p_tied) tie_hits++;

  initial begin
    @(negedge clk); ma=1;
    @(negedge clk); ma=0; mb=1; md=1;
    @(negedge clk); mb=1; mc=1; md=2;
    @(negedge clk); mb=0; mc=1;
    @(negedge clk); mc=0;
    repeat (3) @(negedge clk);

    na=1;
    @(negedge clk); na=0; nb=1;
    @(negedge clk); nb=1; nc=1;
    @(negedge clk); nb=0; nc=1;
    @(negedge clk); nc=0;
    repeat (3) @(negedge clk);

    ta=1;
    @(negedge clk); ta=0; tb=1; td=5;
    @(negedge clk); tb=1; td=5;
    @(negedge clk); tb=0; tc=1; td=7;
    @(negedge clk); tc=0; td=9;
    repeat (3) @(negedge clk);

    $display("first_match groups: mid=%0d named=%0d inline=%0d tied=%0d sequence_local=%0d",
             mid_hits, named_hits, inline_hits, tie_hits, sequence_local_hits);
    if (mid_hits != 1 || named_hits != 1 || inline_hits != 1 || tie_hits != 1
	|| sequence_local_hits != 1)
      $fatal(1, "first_match group assignment regression");
    $finish(0);
  end
endmodule
