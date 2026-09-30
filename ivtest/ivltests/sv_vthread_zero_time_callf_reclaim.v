// A returned function call must reclaim its vthread without waiting for
// the Active queue to become empty. Completed call frames were queued for
// DEL_THREAD deletion, which never ran while this zero-time loop kept the
// Active region busy, so memory grew with every call (about 6 GB for 900k
// calls). Covers automatic, output-argument, void, nested and class-method
// calls, whose join paths all reap the callee, and a function called from a
// continuous assignment (a .ufunc thread per evaluation) driven by #0 steps.
class counter;
  int v;
  function void bump(int d); v += d; endfunction
  function int get(); return v; endfunction
endclass

module sv_vthread_zero_time_callf_reclaim #(
  parameter int ITERATIONS = 250_000
);
  counter c = new;
  longint sum;
  int errors;

  function automatic int inc(int x); return x + 1; endfunction
  function automatic void split(input int x, output int lo, output int hi);
    lo = x & 16'hffff;
    hi = x >> 16;
  endfunction
  function automatic int twice(int x); return inc(inc(x)) - 2 + x; endfunction
  function int triple(int a); return a * 3; endfunction

  int x, y;
  longint usum;
  assign y = triple(x);

  initial begin
    for (int i = 0; i < ITERATIONS; i++) begin
      int lo, hi;
      split(i, lo, hi);
      if (((hi << 16) | lo) != i || inc(i) != i + 1 || twice(i) != 2 * i)
        errors++;
      c.bump(1);
      sum += c.get();
    end
    for (int i = 1; i <= ITERATIONS; i++) begin
      x = i;
      #0;
      usum += y;
    end

    if (errors != 0 || c.get() != ITERATIONS
        || sum != longint'(ITERATIONS) * (ITERATIONS + 1) / 2
        || usum != 3 * sum)
      $display("FAILED -- errors=%0d count=%0d sum=%0d usum=%0d",
               errors, c.get(), sum, usum);
    else
      $display("PASSED");
  end
endmodule
