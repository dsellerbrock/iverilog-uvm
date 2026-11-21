class free_real_unique;
  rand real ra[2];
  rand real singleton[6:6];
  constraint distinct { unique {ra}; unique {singleton}; }
endclass

class finite_real_unique;
  rand real a[2];
  constraint distinct { unique {a}; }
  constraint domain {
    a[0] inside {1.25, 1.5};
    a[1] inside {1.25, 1.75, 2.25};
  }
endclass

class sliced_real_unique;
  rand real a[-1:2];
  rand real peer;
  constraint distinct { unique {a[0:1], peer}; unique {a[1], a[2]}; }
  constraint domain {
    a[0] inside {[0.25:0.75]};
    peer > 0.25 && peer < 0.75;
  }
endclass

class zero_real_unique;
  rand real a[2];
  rand int marker;
  real neg_zero;
  real pinned_peer;
  constraint distinct { unique {a}; }
  constraint domain {
    a[0] inside {0.0, neg_zero, 1.25};
    a[1] == pinned_peer;
  }
  constraint force_zero { a[0] == 0.0; }
endclass

class grid_real_unique;
  rand real a[2][3];
  constraint distinct { unique {a[0:0]}; unique {a[1][1:2]}; }
  constraint domain {
    a[0][0] == 1.0; a[0][1] == 2.0; a[0][2] == 3.0;
    a[1][1] == 1.0; a[1][2] == 2.0;
  }
endclass

class state_real_unique;
  real a[2];
  bit check_unique;
  rand bit [1:0] value, echo;
  constraint integral_pair { value == echo; }
  constraint distinct { if (check_unique) unique {a}; }
endclass

class large_real_unique;
  rand real a[3];
  rand bit [1:0] value, echo;
  constraint integral_pair { value == echo; }
  constraint distinct { unique {a}; }
  // The product has 1331 tuples, above the 1024-tuple enumeration budget.
  constraint domain { foreach (a[i]) a[i] inside {0,1,2,3,4,5,6,7,8,9,10}; }
  constraint endpoints { a[0] < a[2]; }
endclass

module test;
  free_real_unique free_draw;
  finite_real_unique finite_draw;
  sliced_real_unique sliced_draw;
  zero_real_unique zero_draw;
  grid_real_unique grid_draw;
  state_real_unique state_draw;
  large_real_unique large_draw;
  integer seen[2][3];
  integer i, j, first, second, low_count;
  string saved_rng;

  initial begin
    free_draw = new;
    free_draw.srandom(3925);
    repeat (12) begin
      if (!free_draw.randomize() || free_draw.ra[0] == free_draw.ra[1])
        $fatal(1, "unique {ra} failed without interval bounds");
      if ((($realtobits(free_draw.ra[0]) >> 52) & 64'h7ff) == 64'h7ff
          || (($realtobits(free_draw.ra[1]) >> 52) & 64'h7ff) == 64'h7ff)
        $fatal(1, "Unbounded draw was nonfinite");
    end

    finite_draw = new;
    finite_draw.srandom(3925);
    foreach (seen[i,j]) seen[i][j] = 0;
    repeat (600) begin
      if (!finite_draw.randomize()) $fatal(1, "Finite tuple solve failed");
      if (finite_draw.a[0] == 1.25) first = 0;
      else if (finite_draw.a[0] == 1.5) first = 1;
      else $fatal(1, "First axis outside its domain");
      if (finite_draw.a[1] == 1.25) second = 0;
      else if (finite_draw.a[1] == 1.75) second = 1;
      else if (finite_draw.a[1] == 2.25) second = 2;
      else $fatal(1, "Second axis outside its domain");
      seen[first][second]++;
    end
    foreach (seen[i,j])
      if ((i == 0 && j == 0) ? seen[i][j] != 0 : seen[i][j] == 0)
        $fatal(1, "Incorrect legal support at (%0d,%0d)", i, j);
    low_count = seen[0][1] + seen[0][2];
    if (low_count < 210 || low_count > 270)
      $fatal(1, "Expected 2/5 of first-axis draws at 1.25, got %0d/600", low_count);

    sliced_draw = new;
    sliced_draw.srandom(3925);
    sliced_draw.a[-1] = 0.5;
    sliced_draw.a[1] = 0.5;
    sliced_draw.a[2] = 3.0;
    sliced_draw.a[-1].rand_mode(0);
    sliced_draw.a[1].rand_mode(0);
    sliced_draw.a[2].rand_mode(0);
    repeat (16) begin
      if (!sliced_draw.randomize()) $fatal(1, "Slice and real scalar solve failed");
      if (sliced_draw.a[0] < 0.25 || sliced_draw.a[0] > 0.75
          || sliced_draw.peer <= 0.25 || sliced_draw.peer >= 0.75
          || sliced_draw.a[0] == sliced_draw.peer
          || sliced_draw.a[0] == sliced_draw.a[1]
          || sliced_draw.peer == sliced_draw.a[1])
        $fatal(1, "Slice/scalar tuple violated its domains or uniqueness");
      if (sliced_draw.a[-1] != 0.5 || sliced_draw.a[1] != 0.5 || sliced_draw.a[2] != 3.0)
        $fatal(1, "An inactive leaf changed");
    end

    zero_draw = new;
    zero_draw.srandom(3925);
    zero_draw.neg_zero = $bitstoreal(64'h8000000000000000);
    zero_draw.pinned_peer = zero_draw.neg_zero;
    zero_draw.a[1] = zero_draw.neg_zero;
    zero_draw.a[1].rand_mode(0);
    zero_draw.force_zero.constraint_mode(0);
    if (!zero_draw.randomize() || zero_draw.a[0] != 1.25
        || $realtobits(zero_draw.a[1]) !== 64'h8000000000000000)
      $fatal(1, "The inactive negative zero must exclude both zero encodings");

    zero_draw.a[0] = 7.25;
    zero_draw.marker = 42;
    zero_draw.force_zero.constraint_mode(1);
    saved_rng = zero_draw.get_randstate();
    if (zero_draw.randomize()) $fatal(1, "Signed-zero contradiction was accepted");
    if (zero_draw.a[0] != 7.25 || zero_draw.marker != 42
        || $realtobits(zero_draw.a[1]) !== 64'h8000000000000000
        || zero_draw.get_randstate() != saved_rng)
      $fatal(1, "UNSAT changed a value or the RNG state");

    zero_draw.a[1] = 2.25;
    zero_draw.pinned_peer = 2.25;
    zero_draw.force_zero.constraint_mode(0);
    low_count = 0;
    repeat (360) begin
      if (!zero_draw.randomize()) $fatal(1, "Signed-zero point set failed");
      if (zero_draw.a[0] == 0.0) low_count++;
      else if (zero_draw.a[0] != 1.25) $fatal(1, "Draw outside the signed-zero point set");
    end
    if (low_count < 150 || low_count > 210)
      $fatal(1, "Both signed zero encodings must count as one value, got %0d/360", low_count);

    state_draw = new;
    state_draw.a[0] = 0.0;
    state_draw.a[1] = zero_draw.neg_zero;
    if (!state_draw.randomize()) $fatal(1, "A disabled uniqueness guard constrained the solve");
    state_draw.check_unique = 1;
    if (state_draw.randomize()) $fatal(1, "State-only signed zeros were distinct");
    state_draw.a[1] = 1.0;
    if (!state_draw.randomize()) $fatal(1, "Distinct state values were rejected");

    grid_draw = new;
    if (!grid_draw.randomize()
        || grid_draw.a[0][0] != 1.0 || grid_draw.a[0][1] != 2.0 || grid_draw.a[0][2] != 3.0
        || grid_draw.a[1][1] != 1.0 || grid_draw.a[1][2] != 2.0)
      $fatal(1, "Independent multidimensional slices did not solve");

    large_draw = new;
    large_draw.srandom(3925);
    repeat (24) begin
      if (!large_draw.randomize()) $fatal(1, "Large finite product solve failed");
      if (large_draw.value != large_draw.echo) $fatal(1, "Independent integral constraint failed");
      if (large_draw.a[0] == large_draw.a[1] || large_draw.a[0] == large_draw.a[2]
          || large_draw.a[1] == large_draw.a[2])
        $fatal(1, "Large finite product accepted a duplicate");
      if (large_draw.a[0] >= large_draw.a[2])
        $fatal(1, "Large finite product violated a hard tuple predicate");
      for (i = 0; i < 3; i++)
        if (large_draw.a[i] < 0.0 || large_draw.a[i] > 10.0
            || large_draw.a[i] != $itor($rtoi(large_draw.a[i])))
          $fatal(1, "Large finite product drew outside the set");
    end
    $display("PASSED");
  end
endmodule
