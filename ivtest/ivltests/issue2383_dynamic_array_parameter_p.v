module issue2383_dynamic_array_parameter_p;
  parameter int SIZES[] = {4, 8, 16};
  int index;

  initial begin
    if (SIZES.size() != 3)
      $fatal(1, "unexpected parameter size: %0d", SIZES.size());
    foreach (SIZES[index]) begin
      if (SIZES[index] != ((index == 0) ? 4 : (index == 1) ? 8 : 16))
        $fatal(1, "unexpected SIZES[%0d]: %0d", index, SIZES[index]);
    end
    $display("%p size %0d", SIZES, SIZES.size());
  end
endmodule
