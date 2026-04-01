class node_t;
endclass

module test;
  typedef bit seen_t[node_t];

  initial begin
    bit found;
    node_t key;
    seen_t seen;

    found = 1'b0;
    key = new();
    seen[key] = 1'b1;

    if (!seen.exists(key) || seen[key] !== 1'b1) begin
      $display("TYPEDEF_STORE_FAIL");
      $finish(1);
    end

    foreach (seen[cur]) begin
      if (cur == key)
        found = 1'b1;
    end

    if (found) begin
      $display("PASSED");
    end else begin
      $display("TYPEDEF_FAIL");
      $finish(1);
    end
  end
endmodule
