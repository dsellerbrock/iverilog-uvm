// IEEE 1800-2017/2023 18.4: a rand queue member of a rand unpacked struct
// participates in the class solve, including its size and each element.
typedef struct { rand int q[$]; rand int d[]; } issue2890_s_t;

class issue2890_constrained;
  rand issue2890_s_t p;
  constraint c1 {
    p.q.size() == 3;
    p.d.size() == 3;
    foreach (p.q[i]) p.q[i] == i * 10;
    foreach (p.d[i]) p.d[i] == i * 10;
  }
endclass

class issue2890_unconstrained;
  rand issue2890_s_t p;
endclass

module test;
  issue2890_constrained constrained_obj;
  issue2890_unconstrained unconstrained_obj;
  initial begin
    constrained_obj = new;
    if (!constrained_obj.randomize()) $fatal(1, "constrained randomize failed");
    if (constrained_obj.p.q.size() != 3
        || constrained_obj.p.q[0] != 0
        || constrained_obj.p.q[1] != 10
        || constrained_obj.p.q[2] != 20
        || constrained_obj.p.d.size() != 3
        || constrained_obj.p.d[0] != 0
        || constrained_obj.p.d[1] != 10
        || constrained_obj.p.d[2] != 20)
      $fatal(1, "constrained container result was incorrect");
    $display("PASSED");

    unconstrained_obj = new;
    unconstrained_obj.p.q = '{1, 2};
    unconstrained_obj.p.d = '{1, 2};
    if (!unconstrained_obj.randomize())
      $fatal(1, "unconstrained randomize failed");
    if (unconstrained_obj.p.q.size() != 2 || unconstrained_obj.p.d.size() != 2)
      $fatal(1, "unconstrained container size changed");
    $display("%0d %0d", unconstrained_obj.p.q.size(),
             unconstrained_obj.p.d.size());
    $finish;
  end
endmodule
