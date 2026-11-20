interface path_bus;
  wire a;
  logic y;
  modport data(input a, output y);
endinterface

module driver(path_bus.data ch, output wire own);
  assign ch.y = ch.a;
  assign own = ch.y;
  specify
    (ch.a => ch.y) = 5;
  endspecify
endmodule

module wrapper(path_bus.data p);
  wire own, seen;
  driver d(p, own);
  assign seen = p.y;
endmodule

module top;
  path_bus i();
  wrapper w(i.data);
  logic stimulus = 0;
  assign i.a = stimulus;

  initial begin
    #10 stimulus = 1;
    #1;
    if ({w.own, w.seen, i.y} !== 3'b100)
      $fatal(1, "t=%0t owner/wrapper/interface=%b%b%b, expected 100",
             $time, w.own, w.seen, i.y);
    #3;
    if (i.y !== 1'b0)
      $fatal(1, "External output changed before t=15");
    #1;
    #0;  // Sample after the path's Active-region update at t=15.
    if (i.y !== 1'b1)
      $fatal(1, "External output did not rise at t=15");
    #1;
    if ({w.own, w.seen, i.y} !== 3'b111)
      $fatal(1, "t=%0t owner/wrapper/interface=%b%b%b, expected 111",
             $time, w.own, w.seen, i.y);
    $display("PASSED");
  end
endmodule
