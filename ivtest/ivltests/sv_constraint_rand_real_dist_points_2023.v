class real_dist_points;
  rand real value;

  constraint choices {
    value dist {0.25 := 1, 0.5 := 0, 0.75 :/ 3};
  }
endclass

class real_dist_no_feasible_point;
  rand real value;

  constraint choices {
    value == 0.75;
    value dist {0.25 := 1};
  }
endclass

class real_dist_mixed_points;
  rand real value;

  constraint choices {
    value dist {-1 := 1, 0.5 :/ 1};
  }
endclass

class real_dist_range_boundary;
  rand real value;

  constraint choices {
    value dist {[0.25:0.75] :/ 1};
  }
endclass

class real_dist_additional_range;
  rand real value;

  constraint a_point {
    value dist {0.25 := 1};
  }

  constraint b_range {
    value dist {[0.1:0.5] :/ 1};
  }
endclass

module test;
  real_dist_points item;
  real_dist_no_feasible_point impossible;
  real_dist_mixed_points mixed;
  real_dist_range_boundary range_boundary;
  real_dist_additional_range additional_range;
  integer low_count, high_count, integral_count, mixed_real_count;

  initial begin
    item = new;
    item.srandom(1800);
    low_count = 0;
    high_count = 0;

    repeat (4096) begin
      if (!item.randomize())
        $fatal(1, "real point distribution randomize failed");

      if (item.value == 0.25)
        low_count++;
      else if (item.value == 0.75)
        high_count++;
      else
        $fatal(1, "unexpected real point %0.17g", item.value);
    end

    if (low_count < 850 || low_count > 1200)
      $fatal(1, "real point weights were not respected: %0d:%0d",
             low_count, high_count);

    impossible = new;
    impossible.value = 0.75;
    if (impossible.randomize())
      $fatal(1, "infeasible real dist point unexpectedly randomized");
    if (impossible.value != 0.75)
      $fatal(1, "failed real point randomize changed the property");

    mixed = new;
    mixed.srandom(1801);
    integral_count = 0;
    mixed_real_count = 0;
    repeat (256) begin
      if (!mixed.randomize())
        $fatal(1, "mixed real/integral dist randomize failed");
      if (mixed.value == -1.0)
        integral_count++;
      else if (mixed.value == 0.5)
        mixed_real_count++;
      else
        $fatal(1, "unexpected mixed real dist point %0.17g", mixed.value);
    end
    if (integral_count == 0 || mixed_real_count == 0)
      $fatal(1, "mixed real/integral dist item was never sampled");

    range_boundary = new;
    range_boundary.value = 0.5;
    if (range_boundary.randomize())
      $fatal(1, "unsupported real dist range unexpectedly randomized");
    if (range_boundary.value != 0.5)
      $fatal(1, "unsupported real dist range changed the property");

    additional_range = new;
    additional_range.value = 0.75;
    if (additional_range.randomize())
      $fatal(1, "unsupported additional real dist range unexpectedly randomized");
    if (additional_range.value != 0.75)
      $fatal(1, "unsupported additional real dist range changed the property");

    $display("PASSED: finite real dist points and failure boundaries");
  end
endmodule
