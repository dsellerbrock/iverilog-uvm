module test;
  class base_t;
    virtual function void initialize();
    endfunction
  endclass

  class derived_t extends base_t;
    int hits;

    function void initialize();
      hits += 1;
    endfunction
  endclass

  initial begin
    base_t q[$];
    derived_t d;
    int idx;

    d = new;
    q.push_back(d);

    foreach (q[idx]) begin
      q[idx].initialize();
    end

    if (d.hits !== 1) begin
      $display("FAILED -- d.hits=%0d, expected 1", d.hits);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
