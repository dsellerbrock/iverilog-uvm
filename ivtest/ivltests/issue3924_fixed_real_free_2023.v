class free_real_array;
  rand real x[-1:0][2:3];
  rand real singleton[6:6];
endclass

module test;
  free_real_array a, b;
  bit saw_positive[-1:0][2:3];
  bit saw_negative[-1:0][2:3];
  bit [63:0] before_x[-1:0][2:3];

  initial begin
    a = new;
    b = new;
    a.srandom(3924);
    b.srandom(3924);
    repeat (24) begin
      if (!a.randomize() || !b.randomize()) $fatal(1, "Unconstrained solve failed");
      foreach (saw_positive[i,j]) begin
        if ($realtobits(a.x[i][j]) !== $realtobits(b.x[i][j]))
          $fatal(1, "Replay diverged at [%0d][%0d]", i, j);
        if ((($realtobits(a.x[i][j]) >> 52) & 64'h7ff) == 64'h7ff)
          $fatal(1, "Nonfinite draw at [%0d][%0d]", i, j);
        if (a.x[i][j] > 1.0e306) saw_positive[i][j] = 1;
        if (a.x[i][j] < -1.0e306) saw_negative[i][j] = 1;
      end
      if ($realtobits(a.singleton[6]) !== $realtobits(b.singleton[6])
          || a.singleton[6] == 0.0
          || (($realtobits(a.singleton[6]) >> 52) & 64'h7ff) == 64'h7ff)
        $fatal(1, "Singleton did not receive a finite replayable draw");
    end
    foreach (saw_positive[i,j])
      if (!saw_positive[i][j] || !saw_negative[i][j])
        $fatal(1, "Missing large positive or negative draws at [%0d][%0d]", i, j);

    a.singleton[6] = 0.125;
    a.singleton[6].rand_mode(0);
    if (!a.randomize() || a.singleton[6] != 0.125)
      $fatal(1, "Singleton rand_mode did not preserve its value");
    foreach (before_x[i,j]) before_x[i][j] = $realtobits(a.x[i][j]);
    if (!a.randomize(singleton) || a.singleton[6] == 0.125)
      $fatal(1, "Explicit selection did not randomize the singleton");
    foreach (before_x[i,j])
      if ($realtobits(a.x[i][j]) !== before_x[i][j])
        $fatal(1, "Explicit selection changed an unselected leaf");
    $display("PASSED");
  end
endmodule
