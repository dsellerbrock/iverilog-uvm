// IEEE 1800-2017 18.7.1: an unqualified name in an inline constraint first
// denotes a randomized-object property. If no such property exists, a queue
// declared in the calling class method is sampled as caller state. Explicit
// local:: always selects that caller-scope queue.
module main;
  class local_queue_item;
    rand bit [3:0] mask;

    function automatic bit check_local_queue();
      automatic byte unsigned q[$] = '{8'h11, 8'h22, 8'h33, 8'h44};
      automatic int ok;

      mask = '0;
      ok = randomize(mask) with {
        mask == 4'hf;
        $countones(mask) <= q.size();
      };
      if (!ok || mask != 4'hf)
        return 0;

      mask = '0;
      ok = randomize(mask) with {
        mask == 4'hf;
        $countones(mask) <= local::q.size();
      };
      return ok && mask == 4'hf;
    endfunction
  endclass

  class shadow_queue_item;
    rand bit [3:0] mask;
    byte unsigned q[$];

    function new();
      q = '{8'h11, 8'h22, 8'h33, 8'h44};
    endfunction

    function automatic bit check_precedence();
      automatic byte unsigned q[$] = '{8'haa, 8'hbb};
      automatic int ok;

      // The class property wins for the unqualified spelling, so four set
      // bits are satisfiable even though the colliding method local has two
      // elements.
      mask = '0;
      ok = randomize(mask) with {
        mask == 4'hf;
        $countones(mask) <= q.size();
      };
      if (!ok || mask != 4'hf)
        return 0;

      // local:: bypasses target-property precedence and observes the
      // two-element method-local queue, making the same request UNSAT.
      ok = randomize(mask) with {
        mask == 4'hf;
        $countones(mask) <= local::q.size();
      };
      return !ok;
    endfunction
  endclass

  initial begin
    automatic local_queue_item local_item = new;
    automatic shadow_queue_item shadow_item = new;

    if (local_item.check_local_queue() && shadow_item.check_precedence())
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
