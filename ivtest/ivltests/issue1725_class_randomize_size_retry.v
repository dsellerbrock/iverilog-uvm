class holder;
  rand bit [7:0] d[];
  constraint c {
    d.size() inside {[0:3]};
    foreach (d[i]) d[i] == 8'h00 && d[i] == 8'h01;
  }
endclass

class fixed_failure;
  rand bit [7:0] d[];
  constraint c {
    d.size() == 1;
    foreach (d[i]) d[i] == 8'h00 && d[i] == 8'h01;
  }
endclass

module tb;
  holder h = new;
  fixed_failure bad = new;
  int empty_successes;
  int fixed_failures;
  int rollbacks;
  int errors;
  bit ok;

  initial begin
    repeat (20) begin
      ok = h.randomize();
      if (ok && h.d.size() == 0) empty_successes++;
      else errors++;
    end

    repeat (5) begin
      ok = bad.randomize();
      if (!ok) fixed_failures++;
      else errors++;
      if (bad.d.size() == 0) rollbacks++;
      else errors++;
    end

    $display("empty %0d fixed_fail %0d rollback %0d errors %0d",
             empty_successes, fixed_failures, rollbacks, errors);
    if (errors == 0) $display("PASSED");
  end
endmodule
