module issue3391_covdb;
  covergroup cg with function sample(bit a, bit b);
    type_option.merge_instances = 0;
    ca: coverpoint a { bins zero = {0}; bins one = {1}; }
    cb: coverpoint b { bins zero = {0}; bins one = {1}; }
    ab: cross ca, cb;
  endgroup
  cg c;
  int covered, total;
  real score;
  string path;
  bit saving;

  task automatic check(string name, real expected_score,
                       int expected_covered, int expected_total);
    if (score < expected_score - 0.01 || score > expected_score + 0.01 ||
        covered != expected_covered || total != expected_total)
      $fatal(1, "%s: got %0.2f %0d/%0d, expected %0.2f %0d/%0d",
             name, score, covered, total,
             expected_score, expected_covered, expected_total);
  endtask

  initial begin
    // +SAVE=<path> generates the fixture. +LOAD=<path> checks another copy.
    saving = $value$plusargs("SAVE=%s", path);
    if (saving)
      $set_coverage_db_name(path);
    else begin
      if (!$value$plusargs("LOAD=%s", path))
        path = "ivltests/issue3391_covdb.db";
      $load_coverage_db(path);
    end
    c = new;
    if (saving) begin
      c.sample(0, 0);
      c.sample(0, 1);
    end

    score = c.get_coverage(covered, total);
    check("group", 66.67, 5, 8);
    score = c.ca.get_coverage(covered, total);
    check("coverpoint ca", 50.0, 1, 2);
    score = c.cb.get_coverage(covered, total);
    check("coverpoint cb", 100.0, 2, 2);
    score = c.ab.get_coverage(covered, total);
    check("cross", 50.0, 2, 4);

    if (!saving) begin
      $load_coverage_db(path);
      score = c.get_coverage(covered, total);
      check("two loads", 66.67, 10, 16);
      c.sample(1, 0);
      score = c.get_coverage(covered, total);
      check("loaded and live group", 58.33, 13, 24);
      score = c.ab.get_coverage(covered, total);
      check("loaded and live cross", 41.67, 5, 12);
    end
    $display("PASSED");
  end
endmodule
