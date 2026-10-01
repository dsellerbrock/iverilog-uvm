// break and continue inside labeled blocks of a task, function or class
// method. A labeled begin..end in an automatic subroutine is its own scope
// without its own frame; the break/continue it left pending was never
// dispatched to the enclosing loop, so the loop kept running (a hang for
// forever loops).
class worker;
  int n, after, outer_iters;

  task nested_forever();
    n = 0; after = 0; outer_iters = 0;
    forever begin : window_loop
      forever begin : sample_loop
        n++;
        if (n % 3 == 0) break;
      end : sample_loop
      after++;
      if (n >= 9) break;
      outer_iters++;
    end : window_loop
  endtask

  function int count_odd(int limit);
    int odd = 0;
    for (int i = 0; i < limit; i++) begin : body
      if (i % 2 == 0) continue;
      odd++;
    end : body
    return odd;
  endfunction

  function int first_multiple(int divisor);
    int i = 0;
    while (1) begin : scan
      i++;
      begin : check
        if (i % divisor == 0) break;
      end : check
    end : scan
    return i;
  endfunction

  function int do_while_skip();
    int i = 0, sum = 0;
    do begin : step
      i++;
      if (i == 3) continue;
      if (i > 6) break;
      sum += i;
    end while (i < 100);
    return sum;
  endfunction
endclass

module main;
  int errors;
  int tn;

  task automatic labeled_task(output int hits);
    hits = 0;
    for (int i = 0; i < 10; i++) begin : body
      if (i == 7) break;
      if (i % 2) continue;
      hits++;
    end : body
  endtask

  initial begin
    automatic worker w = new;
    automatic int hits;

    w.nested_forever();
    if (w.n != 9 || w.after != 3 || w.outer_iters != 2) begin
      $display("FAILED nested forever n=%0d after=%0d outer=%0d", w.n, w.after, w.outer_iters);
      errors++;
    end
    if (w.count_odd(10) != 5) begin $display("FAILED count_odd %0d", w.count_odd(10)); errors++; end
    if (w.first_multiple(7) != 7) begin $display("FAILED first_multiple %0d", w.first_multiple(7)); errors++; end
    // sum of 1,2,4,5,6 (3 skipped, loop stops at 7)
    if (w.do_while_skip() != 18) begin $display("FAILED do_while_skip %0d", w.do_while_skip()); errors++; end
    labeled_task(hits);
    if (hits != 4) begin $display("FAILED labeled_task hits=%0d", hits); errors++; end

    if (errors == 0) $display("PASSED");
  end
endmodule
