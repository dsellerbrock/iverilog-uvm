// G35 probe: unpacked array .reverse()
module p58_reverse_method;

  initial begin
    int u[5] = '{1, 2, 3, 4, 5};
    u.reverse();
    if (u[0] == 5 && u[1] == 4 && u[2] == 3 && u[3] == 2 && u[4] == 1)
      $display("PASS");
    else
      $display("FAIL: got '{%0d,%0d,%0d,%0d,%0d}",
               u[0], u[1], u[2], u[3], u[4]);
  end

endmodule
