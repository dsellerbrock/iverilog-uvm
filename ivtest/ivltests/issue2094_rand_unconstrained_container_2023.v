module issue2094_rand_unconstrained_container;
  class c;
    rand int q[$];
    rand int d[];
    rand int x;
  endclass

  class k;
    rand int q[$];
    constraint s { q.size() == 3; }
  endclass

  initial begin
    c o;
    k ok;
    int same;
    int initial_d;
    int initial_k;
    int r[$];

    r = '{30, 10, 20};
    o = new;
    ok = new;
    o.q = r;
    o.d = r;
    ok.q = r;
    initial_d = o.d[0];
    initial_k = ok.q[0];
    same = 0;

    repeat (32) begin
      if (!o.randomize() || !ok.randomize()) $fatal(1, "randomize failed");
      if (o.q.size() != 3 || o.d.size() != 3 || ok.q.size() != 3)
        $fatal(1, "unconstrained container size changed");
      same += o.q == r;
    end

    if (same == 32) $fatal(1, "unconstrained rand queue was not randomized");
    if (o.d[0] == initial_d)
      $fatal(1, "unconstrained rand dynamic array was not randomized");
    if (ok.q[0] == initial_k)
      $fatal(1, "rand queue named by size() was not randomized");
    $display("rand dynamic container elements randomized; sizes held");
    $display("PASSED");
  end
endmodule
