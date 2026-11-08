// Issue #2228: a randc leaf coupled into an ordered solve whose joint
// solution set (2048 tuples) is past the solver's enumeration cap.
// IEEE 1800-2023 18.5.9: "a 'solve...before...' constraint does not change
// the solution space and, therefore, cannot cause the solver to fail".
// 18.4.2: randc variables are solved first; here every randc value has
// solutions, so randomize() never fails.
//
// 200 draws: randc covers both values exactly 100 times (complete cycles);
// wide is uniform over its 2048 legal values given the solve order, so about
// 190.6 of the 200 draws are distinct (standard deviation about 3); the
// bound of 175 fails a uniform sampler with probability below 1e-6.
class leaf; randc bit cyc; endclass
class item; rand bit [10:0] wide; rand bit dep; rand leaf l;
  constraint c { wide[0] == l.cyc; dep == wide[0]; } constraint o { solve wide before dep; }
  function new; l = new; endfunction endclass
module issue2228_randc_ordered_cap;
  item t = new;
  int ok = 0, cyc_count[2], failed = 0;
  int seen[int];
  initial begin
    t.srandom(32'h2228);
    t.l.srandom(32'h2229);
    repeat (200) begin
      ok += t.randomize();
      if (t.wide[0] != t.l.cyc || t.dep != t.wide[0]) begin
        $display("FAILED: constraint violated wide=%h dep=%0d cyc=%0d", t.wide, t.dep, t.l.cyc);
        failed++;
      end
      cyc_count[t.l.cyc]++;
      seen[t.wide] = 1;
    end
    if (ok != 200) begin $display("FAILED: %0d of 200 calls succeeded", ok); failed++; end
    if (cyc_count[0] != 100 || cyc_count[1] != 100) begin
      $display("FAILED: randc counts %0d/%0d", cyc_count[0], cyc_count[1]); failed++;
    end
    if (seen.num() < 175) begin $display("FAILED: only %0d distinct wide values", seen.num()); failed++; end
    if (failed == 0) $display("PASSED");
  end
endmodule
