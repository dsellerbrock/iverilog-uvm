// IEEE 1800-2023 17.7 / 17.7.2 free checker variables (`rand').
//   r  active, unconstrained: a new random value at every time step.
//   c  `rand const': one random value for the whole run.
//   a  initialized: 0 in the first time step, random afterwards.
//   t  assigned by always_ff, so inactive: it only toggles.
//   fv read by an assertion: its current value, not a Preponed sample.
//   f  in a checker with an assumption: sorry, unconstrained.
// The values are random; the test checks their behaviour, not values.
checker rv(logic clk, output logic [1:0] o);
  rand bit [1:0] r;
  always_ff @(posedge clk) o <= r;
endchecker

checker kc(logic clk, output logic [7:0] k, output bit z, output bit tt);
  rand const bit [7:0] c;
  rand bit [3:0] a = 4'd0;
  rand bit t;
  always_ff @(posedge clk) t <= !t;
  always_ff @(posedge clk) begin k <= c; z <= (a == 0); tt <= t; end
endchecker

// An assertion reads an active free variable's current value (17.7.2: "A
// sampled value of an active checker variable is defined as its current
// value"), so its verdict agrees with the value its action block sees.
checker cv(logic clk);
  rand bit fv;
  a1: assert property (@(posedge clk) fv)
        begin if (!fv) sva_checker_free.n_disagree++; sva_checker_free.n_pass++; end
      else
        begin if (fv) sva_checker_free.n_disagree++; sva_checker_free.n_fail++; end
endchecker

// A checker with an assumption: assume-based randomization (17.7.2) is not
// supported, so its active free variable is unconstrained, with a sorry.
checker am(logic clk);
  rand bit f;
  m: assume property (@(posedge clk) f || !f);
endchecker

module sva_checker_free;
  logic clk = 0;
  logic [1:0] o;
  logic [7:0] k, k0;
  bit z, tt, tt0;
  int seen[4], kchanged, zcount, toggles;
  int n_pass, n_fail, n_disagree;
  always #5 clk = ~clk;
  rv u_rv(clk, o);
  kc u_kc(clk, k, z, tt);
  am u_am(clk);
  cv u_cv(clk);
  initial begin
    @(posedge clk); #1 k0 = k; tt0 = tt;
    repeat (200) begin
      @(posedge clk); #1;
      seen[o] += 1;
      if (k != k0) kchanged += 1;
      if (z) zcount += 1;
      if (tt != tt0) toggles += 1;
      tt0 = tt;
    end
    $display("r values seen: %0d %0d %0d %0d", seen[0] > 0, seen[1] > 0,
             seen[2] > 0, seen[3] > 0);
    $display("c changed: %0d", kchanged);
    $display("a random later: %0d", zcount < 100);
    $display("t toggled every clock: %0d", toggles == 200);
    $display("fv verdicts agree: %0d (both outcomes seen: %0d)",
             n_disagree == 0, n_pass > 0 && n_fail > 0);
    $finish(0);
  end
endmodule
