class phase_t;
  typedef bit edges_t[phase_t];
  edges_t succ;

  function phase_t find(phase_t target);
    if (target == this)
      return target;
    return m_find_successor(target);
  endfunction

  function phase_t m_find_successor(phase_t target);
    foreach (succ[s]) begin
      if (s == target)
        return s;
    end
    return null;
  endfunction
endclass

module test;
  initial begin
    phase_t a, b;

    a = new();
    b = new();
    a.succ[b] = 1'b1;

    if (!a.succ.exists(b)) begin
      $display("FAILED -- exists");
      $finish;
    end

    if (a.find(b) != b) begin
      $display("FAILED -- find");
      $finish;
    end

    $display("PASSED");
  end
endmodule
