module sv_force_binary_rhs_live;
  logic [15:0] dst;
  logic [15:0] src;

  task automatic expect_dst(input logic [15:0] expected,
                            input int step);
    if (dst !== expected) begin
      $display("FAILED step=%0d actual=%h expected=%h",
               step, dst, expected);
      $finish;
    end
  endtask

  initial begin
    dst = 16'h1234;
    src = 16'h1000;
    force dst = src - 16'd1;
    #0 expect_dst(16'h0fff, 1);

    // Procedural writes cannot override a force, and every source change
    // must reevaluate the full binary expression while the force is active.
    dst = 16'haaaa;
    #0 expect_dst(16'h0fff, 2);
    src = 16'h0001;
    #0 expect_dst(16'h0000, 3);
    src = 16'h0000;
    #0 expect_dst(16'hffff, 4);

    // Releasing a variable retains its final forced value. The former RHS
    // must then be disconnected, and an ordinary write takes effect again.
    release dst;
    #0 expect_dst(16'hffff, 5);
    src = 16'h0042;
    #0 expect_dst(16'hffff, 6);
    dst = 16'h1357;
    #0 expect_dst(16'h1357, 7);

    $display("PASSED");
  end
endmodule
