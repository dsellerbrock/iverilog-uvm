// IEEE 1800-2017/2023 16.9.1, 16.9.9 and 16.9.10.
module issue2994_throughout_within;
  bit clk;
  bit a = 1, b = 1, c = 1, d = 1, e = 1;

  assert property (@(posedge clk) a throughout b ##1 c within d ##1 e)
    else $fatal(1, "unparenthesized reducer");
  assert property (@(posedge clk) (a throughout (b ##1 c)) within (d ##1 e))
    else $fatal(1, "parenthesized reducer");

  bit guard, inner_start, inner_end, window_start, window_end, launch, first_window;
  int plain_hits, grouped_hits, named_hits, clocked_hits, wrapped_hits;
  int antecedent_passes, consequent_passes, both_passes;
  int left_hits, right_hits;

  sequence combined;
    guard throughout inner_start ##[2:3] inner_end
      within window_start ##4 window_end;
  endsequence

  cover property (@(posedge clk)
    guard throughout inner_start ##2 inner_end within window_start ##4 window_end)
    plain_hits++;
  cover property (@(posedge clk)
    (guard throughout (inner_start ##2 inner_end)) within (window_start ##4 window_end))
    grouped_hits++;
  cover property (@(posedge clk) combined) named_hits++;
  cover property (@(posedge clk)
    (guard throughout (inner_start ##[2:3] inner_end))
      within (@(posedge clk) window_start ##4 window_end))
    clocked_hits++;
  cover property (@(posedge clk) 1'b1 throughout combined) wrapped_hits++;

  assert property (@(posedge clk)
    (guard throughout inner_start ##[2:3] inner_end
      within (@(posedge clk) window_start ##4 window_end)) |-> window_end)
    antecedent_passes++;
    else $fatal(1, "antecedent ended before the window");
  assert property (@(posedge clk)
    launch |-> guard throughout inner_start ##[2:3] inner_end
      within (@(posedge clk) window_start ##4 window_end))
    consequent_passes++;
    else $fatal(1, "consequent failed");
  assert property (@(posedge clk)
    (guard throughout inner_start ##[2:3] inner_end within first_window ##4 window_end)
      |=> (guard throughout inner_start ##[2:3] inner_end within window_start ##4 window_end))
    both_passes++;
    else $fatal(1, "second window did not start on the next tick");

  // window_start is in the outer window, before the middle interval.
  cover property (@(posedge clk)
    window_start within (inner_start ##2 inner_end) within (window_start ##4 window_end))
    left_hits++;
  cover property (@(posedge clk)
    window_start within ((inner_start ##2 inner_end) within (window_start ##4 window_end)))
    right_hits++;

  task automatic tick(input int age, input bit gap_guard, late_inner, start_implication, start_first = 0);
    window_start = age == 0;
    window_end = age == 4;
    inner_start = age == (late_inner ? 3 : 1);
    inner_end = age == (late_inner ? 5 : 3);
    guard = (age == 1 || (age == 2 && gap_guard) || age == 3)
            || (late_inner && (age == 4 || age == 5));
    launch = window_start && start_implication;
    first_window = window_start && start_first;
    #5 clk = 1;
    #1 clk = 0;
  endtask

  task automatic check_matches(input int expected);
    if (plain_hits != expected || grouped_hits != expected ||
        named_hits != expected || clocked_hits != expected || wrapped_hits != expected)
      $fatal(1, "match count %0d expected, got %0d %0d %0d %0d %0d",
             expected, plain_hits, grouped_hits, named_hits, clocked_hits, wrapped_hits);
  endtask

  initial begin
    $assertvacuousoff(0);

    // The guard holds only in the middle three ticks of the five-tick window.
    // A second successful window starts one tick after the first endpoint.
    for (int window = 0; window < 2; window++) begin
      for (int age = 0; age < 4; age++) begin
        tick(age, 1, 0, 1, window == 0);
        check_matches(window);
        if (antecedent_passes != window || consequent_passes != window || both_passes)
          $fatal(1, "implication completed before the outer endpoint");
      end
      tick(4, 1, 0, 1);
      check_matches(window + 1);
      if (antecedent_passes != window + 1 || consequent_passes != window + 1 ||
          both_passes != window || left_hits != 0 || right_hits != window + 1)
        $fatal(1, "wrong implication endpoint or within associativity");
    end

    // The first replay has a false guard on the delay tick. The next has
    // an inner match whose end lies beyond the containing window.
    for (int replay = 0; replay < 2; replay++) begin
      for (int age = 0; age < 7; age++) begin
        tick(age, replay != 0, replay != 0, 0);
        check_matches(2);
        if (antecedent_passes != 2 || consequent_passes != 2 || both_passes != 1)
          $fatal(1, "implication matched a rejected replay");
      end
    end

    $display("PASS");
    $finish(0);
  end
endmodule
