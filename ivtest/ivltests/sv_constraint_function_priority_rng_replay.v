function automatic int count_ones(bit [9:0] value);
  for (count_ones = 0; value != 0; value = value >> 1)
    count_ones += value & 1'b1;
endfunction

class C;
  rand bit [9:0] value;
  rand bit [3:0] length;
  constraint c {
    length == count_ones(value);
    length < 3;
  }
endclass

module test;
  C a, b, c;
  bit ok_a[200], ok_b[200];
  bit [9:0] value_a[200], value_b[200];
  bit [3:0] length_a[200], length_b[200];
  bit ok_first[100], ok_x[100], ok_y[100];
  bit [9:0] value_first[100], value_x[100], value_y[100];
  bit [3:0] length_first[100], length_x[100], length_y[100];
  bit [9:0] saved_value;
  bit [3:0] saved_length;
  string state;
  int successful_calls;

  initial begin
    a = new;
    b = new;
    a.srandom(7);
    b.srandom(7);
    for (int i = 0; i < 200; i++) begin
      ok_a[i] = a.randomize();
      value_a[i] = a.value;
      length_a[i] = a.length;
      ok_b[i] = b.randomize();
      value_b[i] = b.value;
      length_b[i] = b.length;
      if (ok_a[i] !== ok_b[i]
          || value_a[i] !== value_b[i]
          || length_a[i] !== length_b[i])
        $fatal(1, "same-seed replay differs at call %0d", i);
    end

    c = new;
    c.srandom(7);
    for (int i = 0; i < 100; i++)
      void'(c.randomize());
    state = c.get_randstate();
    saved_value = c.value;
    saved_length = c.length;
    for (int i = 0; i < 100; i++) begin
      ok_first[i] = c.randomize();
      value_first[i] = c.value;
      length_first[i] = c.length;
      if (ok_first[i])
        successful_calls++;
    end
    if (successful_calls == 0)
      $fatal(1, "recorded replay segment contains no successes");

    c.set_randstate(state);
    for (int i = 0; i < 100; i++) begin
      ok_x[i] = c.randomize();
      value_x[i] = c.value;
      length_x[i] = c.length;
      // Failed calls preserve old fields, so X compares fields only on success.
      if (ok_first[i] !== ok_x[i]
          || (ok_first[i]
              && (value_first[i] !== value_x[i]
                  || length_first[i] !== length_x[i])))
        $fatal(1, "RNG-only set_randstate replay differs at call %0d", i);
    end

    c.set_randstate(state);
    c.value = saved_value;
    c.length = saved_length;
    for (int i = 0; i < 100; i++) begin
      ok_y[i] = c.randomize();
      value_y[i] = c.value;
      length_y[i] = c.length;
      if (ok_first[i] !== ok_y[i]
          || value_first[i] !== value_y[i]
          || length_first[i] !== length_y[i])
        $fatal(1, "full-state set_randstate replay differs at call %0d", i);
    end
    $display("PASSED same_seed=200 replay_X=100 replay_Y=100");
    $display("PASSED");
  end
endmodule
