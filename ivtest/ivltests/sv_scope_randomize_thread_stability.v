module main;
  int x, y;
  int expected_x, expected_y;
  process px, py;

  initial begin
    fork
      begin
`ifdef SWAP
        #1;
`endif
        px = process::self();
        px.srandom(32'h1170_0001);
        if (!std::randomize(x)) $fatal(1, "x randomize failed");
        px.srandom(32'h1170_0001);
        expected_x = $urandom;
        if (x !== expected_x)
          $fatal(1, "x scope randomize did not use its process RNG");
      end
      begin
`ifndef SWAP
        #1;
`endif
        py = process::self();
        py.srandom(32'h1170_0002);
        if (!std::randomize(y)) $fatal(1, "y randomize failed");
        py.srandom(32'h1170_0002);
        expected_y = $urandom;
        if (y !== expected_y)
          $fatal(1, "y scope randomize did not use its process RNG");
      end
    join
    $display("PASSED");
  end
endmodule
