module test;
  class base_t;
  endclass

  class left_t extends base_t;
  endclass

  class right_t extends base_t;
  endclass

  function automatic left_t cast_left(base_t obj);
    if (!$cast(cast_left, obj)) begin
      $display("FAIL cast_left failed");
      $finish(1);
    end
  endfunction

  function automatic right_t cast_right(base_t obj);
    if ($cast(cast_right, obj)) begin
      $display("FAIL cast_right unexpectedly succeeded");
      $finish(1);
    end
  endfunction

  initial begin
    left_t left_src;
    base_t base_h;

    left_src = new;
    base_h = left_src;

    if (cast_left(base_h) == null) begin
      $display("FAIL cast_left returned null");
      $finish(1);
    end

    if (cast_right(base_h) != null) begin
      $display("FAIL cast_right clobbered null result");
      $finish(1);
    end

    base_h = null;
    if (cast_left(base_h) != null) begin
      $display("FAIL cast_left null propagation");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
