class bounded_real_array;
  rand real x[-1:1];
  static rand real shared[2:3];
  constraint intervals {
    foreach (x[i])
      if (i == 0) x[i] inside {[0.125:0.875]};
      else x[i] inside {[i + 0.125 : i + 0.875]};
    foreach (shared[j]) shared[j] inside {[j + 0.25 : j + 0.75]};
  }
endclass

module test;
  bounded_real_array a, b;
  real saved[-1:1];
  real saved_shared[2:3];
  bit saw_lower[-1:1];
  bit saw_upper[-1:1];
  string rng_before;

  initial begin
    a = new;
    b = new;
    a.srandom(3924);
    repeat (16) begin
      if (!a.randomize()) $fatal(1, "Finite interval solve failed");
      foreach (saved[i]) begin
        saved[i] = a.x[i];
        if (!(saved[i] >= i + 0.125 && saved[i] <= i + 0.875))
          $fatal(1, "Wrong interval at x[%0d] (%g)", i, saved[i]);
        if (saved[i] < i + 0.5) saw_lower[i] = 1;
        if (saved[i] > i + 0.5) saw_upper[i] = 1;
      end
      foreach (saved_shared[j]) begin
        saved_shared[j] = a.shared[j];
        if (!(saved_shared[j] >= j + 0.25 && saved_shared[j] <= j + 0.75)
            || b.shared[j] != saved_shared[j])
          $fatal(1, "Wrong or unshared value at shared[%0d]", j);
      end
    end
    foreach (saved[i])
      if (!saw_lower[i] || !saw_upper[i])
        $fatal(1, "Both halves of the interval must be sampled at x[%0d]", i);

    a.srandom(800);
    b.srandom(800);
    if (!a.randomize()) $fatal(1, "First seeded solve failed");
    foreach (saved[i]) saved[i] = a.x[i];
    foreach (saved_shared[j]) saved_shared[j] = a.shared[j];
    if (!b.randomize()) $fatal(1, "Second seeded solve failed");
    foreach (saved[i])
      if ($realtobits(b.x[i]) !== $realtobits(saved[i]))
        $fatal(1, "Replay diverged at x[%0d]", i);
    foreach (saved_shared[j])
      if ($realtobits(a.shared[j]) !== $realtobits(saved_shared[j]))
        $fatal(1, "Replay diverged at shared[%0d]", j);

    a.x[0] = 0.5;
    a.x[0].rand_mode(0);
    a.shared[2] = 2.5;
    a.shared[2].rand_mode(0);
    if (b.shared[2].rand_mode() != 0)
      $fatal(1, "Static leaf mode is not shared");
    if (!a.randomize() || a.x[0] != 0.5 || a.shared[2] != 2.5)
      $fatal(1, "In-range disabled leaf was randomized or rejected");
    if (!a.randomize(x) || a.x[0] == 0.5 || a.shared[2] != 2.5)
      $fatal(1, "Explicit selection did not override just the selected property");

    a.x[0] = -0.25;
    foreach (saved[i]) saved[i] = a.x[i];
    foreach (saved_shared[j]) saved_shared[j] = b.shared[j];
    rng_before = a.get_randstate();
    if (a.randomize()) $fatal(1, "Out-of-range disabled leaf was rescued");
    foreach (saved[i])
      if ($realtobits(a.x[i]) !== $realtobits(saved[i]))
        $fatal(1, "Failed call changed x[%0d]", i);
    foreach (saved_shared[j])
      if ($realtobits(b.shared[j]) !== $realtobits(saved_shared[j]))
        $fatal(1, "Failed call changed shared[%0d]", j);
    if (a.get_randstate() != rng_before)
      $fatal(1, "Failed call changed the RNG state");
    $display("PASSED");
  end
endmodule
