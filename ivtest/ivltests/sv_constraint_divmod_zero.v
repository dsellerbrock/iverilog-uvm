// IEEE 1800-2017/2023 11.3.4, 11.3.5 and 18.3.
class guarded_divmod_item;
  int mode;
  int selector;
  bit known_control;
  integer signed_values[2:3];
  bit [7:0] unsigned_values[2:3];
  rand bit witness;
  randc bit [2:0] cycle;
  int posts;

  constraint operations {
    mode == 1 -> (10 / signed_values[selector] == 7);
    mode == 2 -> (10 % signed_values[selector] == 5);
    mode == 3 -> (8'd10 / unsigned_values[selector] == 8'hff);
    mode == 4 -> (8'd10 % unsigned_values[selector] == 8'd10);
    mode == 7 -> !(known_control &&
                   (10 / signed_values[selector] == 7));
    mode == 8 -> (known_control ||
                  (10 % signed_values[selector] == 5));
    if (mode == 9) 10 / signed_values[selector] == 123;
    mode == 10 -> (known_control
                   ? (10 / signed_values[selector] == 7) : 1);
    witness == 1;
  }

  function void post_randomize();
    posts++;
  endfunction
endclass

class wide_zero_divisor;
  int mode;
  rand logic [127:0] divisor;
  rand bit marker;
  constraint forced_zero { divisor == 0; marker == 1; }
  constraint operations {
    mode == 1 -> (128'h8000000000000001_fedcba9876543210
                  / divisor == 128'hffffffffffffffff_ffffffffffffffff);
    mode == 2 -> (128'h8000000000000001_fedcba9876543210
                  % divisor == 128'h8000000000000001_fedcba9876543210);
  }
endclass

class legal_random_divisor;
  rand int divisor;
  rand int quotient;
  constraint legal {
    divisor inside {[0:4]};
    20 / divisor == quotient;
    quotient == 5;
  }
endclass

module test;
  guarded_divmod_item item;
  legal_random_divisor legal;
  wide_zero_divisor wide;
  guarded_divmod_item rollback_probe, rollback_control;
  string rng;
  bit [2:0] saved_cycle;
  bit saved_witness;
  int saved_posts;
  int failed;

  task expect_failure(input int mode, input string label);
    item.mode = mode;
    item.known_control = 0;
    item.srandom(32'h445a0000 + mode);
    rng = item.get_randstate();
    saved_cycle = item.cycle;
    saved_witness = item.witness;
    saved_posts = item.posts;
    if (item.randomize()) begin
      $display("SILENT_SUCCESS %s", label);
      failed++;
    end
    if (item.cycle !== saved_cycle || item.witness !== saved_witness
        || item.posts != saved_posts || item.get_randstate() != rng) begin
      $display("ROLLBACK_FAILURE %s", label);
      failed++;
    end
  endtask

  initial begin
    item = new;
    item.selector = 2;
    item.signed_values[2] = 0;
    item.unsigned_values[2] = 0;

    // Inactive implication and genuinely controlling operands sift errors.
    item.mode = 0;
    if (!item.randomize()) $fatal(1, "inactive implications failed");
    item.mode = 7;
    item.known_control = 0;
    if (!item.randomize()) $fatal(1, "false AND control did not sift");
    item.mode = 8;
    item.known_control = 1;
    if (!item.randomize()) $fatal(1, "true OR control did not sift");
    item.mode = 10;
    item.known_control = 0;
    if (!item.randomize()) $fatal(1, "inactive ternary arm was not sifted");

    // State zero divisors must fail with a focused diagnostic and roll back.
    expect_failure(1, "signed division");
    expect_failure(2, "signed remainder");
    expect_failure(3, "unsigned division");
    expect_failure(4, "unsigned remainder");
    expect_failure(9, "if-guarded signed division");

    wide = new;
    wide.mode = 1;
    if (wide.randomize()) begin
      $display("SILENT_SUCCESS wide division");
      failed++;
    end
    wide.mode = 2;
    if (wide.randomize()) begin
      $display("SILENT_SUCCESS wide remainder");
      failed++;
    end

    // Compare against a seeded twin: a failed evaluation must not consume
    // RNG state or a randc cycle entry.
    rollback_probe = new;
    rollback_control = new;
    rollback_probe.selector = 2;
    rollback_control.selector = 2;
    rollback_probe.signed_values[2] = 0;
    rollback_control.signed_values[2] = 0;
    rollback_probe.srandom(32'h524f4c4c);
    rollback_control.srandom(32'h524f4c4c);
    rollback_probe.mode = 0;
    rollback_control.mode = 0;
    if (!rollback_probe.randomize() || !rollback_control.randomize()
        || rollback_probe.cycle != rollback_control.cycle
        || rollback_probe.witness != rollback_control.witness)
      $fatal(1, "seeded rollback setup diverged");
    rollback_probe.mode = 1;
    if (rollback_probe.randomize())
      $fatal(1, "seeded rollback probe unexpectedly succeeded");
    rollback_probe.mode = 0;
    if (!rollback_probe.randomize() || !rollback_control.randomize()
        || rollback_probe.cycle != rollback_control.cycle
        || rollback_probe.witness != rollback_control.witness
        || rollback_probe.get_randstate() != rollback_control.get_randstate()
        || rollback_probe.posts != rollback_control.posts)
      $fatal(1, "failed solve changed RNG/randc/callback transaction state");

    // Zero is in the declared domain. The valid model must nevertheless use
    // a nonzero divisor because the zero-divisor candidate is an X result.
    legal = new;
    repeat (16) begin
      if (!legal.randomize() || legal.divisor != 4 || legal.quotient != 5)
        $fatal(1, "legal random divisor was rejected or evaluated incorrectly");
    end

    if (failed) $fatal(1, "%0d div/mod zero checks failed", failed);
    $display("PASSED");
  end
endmodule
