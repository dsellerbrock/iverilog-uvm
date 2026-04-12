module test;
  class base_t;
  endclass

  class left_t extends base_t;
  endclass

  class right_t extends base_t;
  endclass

  initial begin
    base_t base_h;
    left_t left_h;
    left_t left_src;
    right_t right_h;

    left_src = new;
    base_h = left_src;
    left_h = null;
    right_h = null;

    if (!$cast(left_h, base_h)) begin
      $display("FAIL cast left");
      $finish(1);
    end

    if (left_h == null) begin
      $display("FAIL left became null");
      $finish(1);
    end

    if ($cast(right_h, base_h)) begin
      $display("FAIL cast right succeeded");
      $finish(1);
    end

    if (right_h != null) begin
      $display("FAIL failed cast clobbered destination");
      $finish(1);
    end

    base_h = null;
    if (!$cast(left_h, base_h)) begin
      $display("FAIL cast null");
      $finish(1);
    end

    if (left_h != null) begin
      $display("FAIL null did not propagate");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
