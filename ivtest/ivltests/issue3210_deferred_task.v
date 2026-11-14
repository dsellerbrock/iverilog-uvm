module test;
  integer n = 5;
  integer seen [0:10];
  integer auto_value = -1;
  integer nba_done = 0;
  task report(input integer id);
    if (nba_done != 1) $fatal(1, "action ran before NBA");
    if (id < -3 || id > 7) $fatal(1, "unexpected argument %0d", id);
    seen[id + 3] = seen[id + 3] + 1;
  endtask
  task automatic auto_report(input integer id);
    auto_value = id;
  endtask
  initial begin
    for (integer i = 0; i < 11; i = i + 1) seen[i] = 0;
    assert #0 (0) else report(-3);
    assert #0 (0) else report(7);
    assert #0 (0) else report(n);
    n = 9;
    for (integer i = 0; i < 3; i = i + 1)
      assert #0 (0) else report(i);
    assert #0 (1) auto_report(n);
    nba_done <= 1;
    n = 10;
    #1;
    for (integer i = 0; i < 11; i = i + 1)
      if (seen[i] != ((i == 0 || i == 3 || i == 4 || i == 5 ||
                       i == 8 || i == 10) ? 1 : 0))
        $fatal(1, "unexpected count for %0d: %0d", i - 3, seen[i]);
    if (auto_value != 9) $fatal(1, "automatic task argument %0d", auto_value);
    $display("PASS");
  end
endmodule
