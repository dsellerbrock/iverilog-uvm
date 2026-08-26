// A method-local queue size in an inline constraint must not be warned and
// dropped. These forced masks are deterministically UNSAT for a two-element
// queue; local:: is the already-supported caller-scope control spelling.
module main;
  class local_queue_item;
    rand bit [3:0] mask;

    function automatic bit check_unqualified_unsat();
      automatic byte unsigned q[$] = '{8'h11, 8'h22};
      automatic int ok;

      ok = randomize(mask) with {
        mask == 4'hf;
        $countones(mask) <= q.size();
      };
      return !ok;
    endfunction

    function automatic bit check_local_qualified_unsat();
      automatic byte unsigned q[$] = '{8'h11, 8'h22};
      automatic int ok;

      ok = randomize(mask) with {
        mask == 4'hf;
        $countones(mask) <= local::q.size();
      };
      return !ok;
    endfunction
  endclass

  initial begin
    automatic local_queue_item item = new;

    if (item.check_unqualified_unsat()
        && item.check_local_qualified_unsat())
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
