class pool_t;
  int data[string];

  function void add(string key, int value);
    data[key] = value;
  endfunction

  function int hit_alpha();
    hit_alpha = 0;
    foreach (data[key]) begin
      if (key == "alpha")
        hit_alpha += 1;
    end
  endfunction
endclass

module test;
  initial begin
    pool_t pool;

    pool = new();
    pool.add("alpha", 1);
    pool.add("beta", 2);

    if (pool.hit_alpha() != 1) begin
      $display("HIT_FAIL %0d", pool.hit_alpha());
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
