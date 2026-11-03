module tb;
  typedef enum logic [15:0] { NA = 16'h1, NB = 16'h2, NC = 16'h3 } nar_e;

  class n;
    rand nar_e a, b;
    constraint c { b != a; }
  endclass

  initial begin
    automatic n m = new;
    int r;

    m.a = nar_e'(16'h99);
    m.a.rand_mode(0);
    r = m.randomize();
    if (r !== 1 || m.a !== nar_e'(16'h99)
        || !(m.b inside {NA, NB, NC}))
      $fatal(1, "inactive enum state was not preserved: r=%0d a=%0h b=%0h",
             r, m.a, m.b);

    m.a.rand_mode(1);
    m.a = nar_e'(16'h99);
    r = m.randomize();
    if (r !== 1 || !(m.a inside {NA, NB, NC})
        || !(m.b inside {NA, NB, NC}))
      $fatal(1, "active enum was not randomized to a literal: r=%0d a=%0h b=%0h",
             r, m.a, m.b);

    $display("PASSED");
  end
endmodule
