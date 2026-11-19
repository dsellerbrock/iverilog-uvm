module sv_assert_first_match_tied;
  bit clk, start, early, after_early;
  int or_hits, and_hits, empty_split_hits, property_hits;
  int overlap_passes, nonoverlap_failures;

  cover sequence (@(posedge clk)
    first_match((start ##1 1'b1) or (start ##[1:2] 1'b1))) or_hits++;

  // Both finishes of the ranged limb are held before the other limb ends.
  cover sequence (@(posedge clk)
    first_match((start ##[1:2] 1'b1) and (start ##4 1'b1))) and_hits++;

  // Delays (1,2) and (2,1) around the empty limb end on the same tick.
  cover sequence (@(posedge clk) first_match(
    (start ##[1:2] 1'b1[*0] ##[1:2] after_early) or
    (start ##3 1'b1))) empty_split_hits++;

  cover property (@(posedge clk)
    first_match((start ##1 1'b1) or (start ##[1:2] 1'b1))) property_hits++;

  assert property (@(posedge clk)
    first_match((start ##1 1'b1) or (start ##[1:2] 1'b1)) |-> early)
    overlap_passes++;
    else $fatal(1, "overlapped consequent checked on the wrong tick");

  assert property (@(posedge clk)
    first_match((start ##1 1'b1) or (start ##[1:2] 1'b1)) |=> !after_early)
    else begin
      if (!after_early) $fatal(1, "nonoverlapped consequent checked on the wrong tick");
      nonoverlap_failures++;
    end

  task tick(input bit s, e, n);
    start = s;
    early = e;
    after_early = n;
    #5 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    $assertvacuousoff(0);
    tick(1, 0, 0);
    if (or_hits || and_hits || empty_split_hits || property_hits ||
        overlap_passes || nonoverlap_failures)
      $fatal(1, "unexpected match at start");

    tick(0, 1, 0);
    if (or_hits != 2 || property_hits != 1 || and_hits || empty_split_hits ||
        overlap_passes != 1 || nonoverlap_failures)
      $fatal(1, "early endpoints: OR=%0d AND=%0d property=%0d pass=%0d fail=%0d",
             or_hits, and_hits, property_hits, overlap_passes, nonoverlap_failures);

    // The delayed OR limb is eligible again here, but the attempt was cut.
    tick(0, 0, 1);
    if (or_hits != 2 || property_hits != 1 || and_hits ||
        overlap_passes != 1 || nonoverlap_failures != 1)
      $fatal(1, "unexpected later OR match or duplicated parent verdict");
    if (empty_split_hits != 2)
      $fatal(1, "tied delays around the empty limb: %0d", empty_split_hits);

    tick(0, 0, 0);
    if (and_hits) $fatal(1, "AND matched before its later limb");
    tick(0, 0, 0);
    if (and_hits != 2 || empty_split_hits != 2)
      $fatal(1, "held AND=%0d or unexpected later empty-split matches=%0d",
             and_hits, empty_split_hits);
    $display("PASS");
    $finish(0);
  end
endmodule
