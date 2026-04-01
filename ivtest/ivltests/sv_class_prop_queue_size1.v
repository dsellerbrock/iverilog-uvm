module test;

  class holder;
    int q[$];

    function void push(int value);
      q.push_back(value);
    endfunction

    function int qsize();
      return q.size();
    endfunction

    function int pop_or_default();
      if (q.size() > 0)
        return q.pop_back();
      return -1;
    endfunction
  endclass

  initial begin
    holder h;
    h = new;

    if (h.qsize() != 0) begin
      $display("FAILED: initial size=%0d", h.qsize());
      $finish(1);
    end

    h.push(11);
    h.push(22);
    if (h.qsize() != 2) begin
      $display("FAILED: push size=%0d", h.qsize());
      $finish(1);
    end

    if (h.pop_or_default() != 22) begin
      $display("FAILED: first pop=%0d", h.pop_or_default());
      $finish(1);
    end

    if (h.qsize() != 1) begin
      $display("FAILED: size after pop=%0d", h.qsize());
      $finish(1);
    end

    if (h.pop_or_default() != 11) begin
      $display("FAILED: second pop=%0d", h.pop_or_default());
      $finish(1);
    end

    if (h.pop_or_default() != -1) begin
      $display("FAILED: empty pop=%0d", h.pop_or_default());
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
