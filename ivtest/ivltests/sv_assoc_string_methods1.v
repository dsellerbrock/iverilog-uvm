class pool_t;
  int data[string];

  function void add(string key, int value);
    data[key] = value;
  endfunction

  function int count();
    string key;
    count = 0;
    if (data.first(key)) begin
      count += 1;
      while (data.next(key))
        count += 1;
    end
  endfunction
endclass

module test;
  initial begin
    pool_t pool;

    pool = new();
    pool.add("alpha", 1);
    pool.add("beta", 2);

    if (pool.count() != 2) begin
      $display("COUNT_FAIL %0d", pool.count());
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
