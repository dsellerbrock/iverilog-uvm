module main;
  int src[3] = '{5, 6, 7};
  int dest[];

  initial begin
    dest = new[2](src);
    if (dest.size() != 2 || dest[0] != 5 || dest[1] != 6)
      $fatal(1, "fixed-array initializer truncation failed");

    dest = new[4](src);
    if (dest.size() != 4 || dest[0] != 5 || dest[1] != 6
        || dest[2] != 7 || dest[3] != 0)
      $fatal(1, "fixed-array initializer padding failed");

    $display("PASSED");
  end
endmodule
