module issue3897_force_concat;
  logic [7:0] source;
  wire [7:0] bus = 8'ha5;

  task automatic check(input logic [7:0] expected);
    if (bus !== expected) $fatal(1, "bus = %h, expected %h", bus, expected);
  endtask

  initial begin
    source = 8'h0f;
    force {bus[7:4], bus[3:0]} = source + 8'h01;
    check(8'h10);
    source = 8'h1f;
    #0 check(8'h20);

    // Releasing part of one leaf keeps its remaining bit live.
    source = 8'h37;
    release bus[2:0];
    check(8'h25);
    #0 check(8'h3d);

    // An overlapping replacement leaves the other bits owned by their
    // original leaves, even though all of them are on the same net.
    force bus[5:4] = 2'b01;
    source = 8'h67;
    #0 check(8'h5d);
    release bus[7:4];
    check(8'had);
    source = 8'h71;
    #0 check(8'ha5);
    release bus[3:0];
    source = 8'hff;
    #0 check(8'ha5);

    $display("PASSED");
  end
endmodule
