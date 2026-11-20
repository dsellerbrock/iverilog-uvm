interface path_bus;
  wire a;
  logic y, shared;
  modport data(input a, output y, input shared);
endinterface

module reader(path_bus.data ch, output wire y, shared);
  assign y = ch.y;
  assign shared = ch.shared;
endmodule

module driver(path_bus.data ch, output wire own, own_shared, child, child_shared);
  assign ch.y = ch.a;
  assign own = ch.y;
  assign own_shared = ch.shared;
  reader r(ch, child, child_shared);
  specify
    (ch.a => ch.y) = 5;
  endspecify
endmodule

module bridge(path_bus.data ch);
  wire own, own_shared, child, child_shared, sibling, sibling_shared;
  driver d(ch, own, own_shared, child, child_shared);
  reader r(ch, sibling, sibling_shared);
endmodule

module wrapper(path_bus.data p);
  bridge b(p);
endmodule

module top;
  path_bus i();
  wrapper w(i.data);
  logic stimulus = 0;
  assign i.a = stimulus;
  wire [3:0] views = {w.b.own, w.b.child, w.b.sibling, i.y};
  wire [3:0] shared_views = {w.b.own_shared, w.b.child_shared,
                             w.b.sibling_shared, i.shared};

  initial begin
    i.shared = 0;
    #10 stimulus = 1;
    i.shared = 1;
    #1;
    if (views !== 4'b1000 || shared_views !== 4'b1111)
      $fatal(1, "t=%0t path=%b shared=%b, expected 1000 and 1111",
             $time, views, shared_views);
    #3;
    if (i.y !== 1'b0)
      $fatal(1, "External output changed before t=15");
    #1;
    #0;  // Sample after the path's Active-region update at t=15.
    if (i.y !== 1'b1)
      $fatal(1, "External output did not rise at t=15");
    #1;
    if (views !== 4'b1111)
      $fatal(1, "t=%0t path=%b, expected 1111", $time, views);
    i.shared = 0;
    #1;
    if (shared_views !== 4'b0000)
      $fatal(1, "t=%0t shared=%b, expected 0000", $time, shared_views);
    $display("PASSED");
  end
endmodule
