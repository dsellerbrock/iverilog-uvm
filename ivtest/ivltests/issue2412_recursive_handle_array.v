// Issue #2412: a class with a handle of its own type, randomized through
// an element of an array of such handles, crashed the code generator: its
// type describer treated the class as a struct and recursed through the
// self-typed handle. IEEE 1800-2023 18.5.8 / 18.6.2: a ring of three
// objects with v + nx.v == 10 solves every v to 5 and runs each
// pre_randomize once; a chain of five runs each pre_randomize once.
module top;
  class ring;
    rand bit [3:0] v;
    rand ring nx;
    int pc;
    constraint c { v + nx.v == 10; }
    function void pre_randomize(); pc++; endfunction
  endclass

  class link;
    rand bit [3:0] v;
    rand link nx;
    int pc;
    constraint c { v < 8; }
    function void pre_randomize(); pc++; endfunction
  endclass

  ring a = new, b = new, c = new;
  link l[5];
  int ok, failures = 0;

  initial begin
    a.nx = b; b.nx = c; c.nx = a;
    ok = a.randomize();
    if (ok != 1 || a.v != 5 || b.v != 5 || c.v != 5
        || a.pc != 1 || b.pc != 1 || c.pc != 1) failures++;
    foreach (l[i]) l[i] = new;
    for (int i = 0; i < 4; i++) l[i].nx = l[i+1];
    ok = l[0].randomize();
    if (ok != 1) failures++;
    foreach (l[i]) if (l[i].pc != 1 || l[i].v >= 8) failures++;
    if (failures == 0) $display("PASSED");
    else $display("FAILED: %0d", failures);
  end
endmodule
