module test;
  class base_t;
    virtual function void hook();
      $display("FAILED -- base hook dispatched");
      $finish(1);
    endfunction
  endclass

  class mid_t extends base_t;
    int hits;

    function void hook();
      hits += 1;
      $display("MID_HOOK");
    endfunction
  endclass

  class leaf_t extends mid_t;
  endclass

  initial begin
    base_t b;
    leaf_t l;

    l = new;
    b = l;
    b.hook();

    if (l.hits !== 1) begin
      $display("FAILED -- l.hits=%0d, expected 1", l.hits);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
