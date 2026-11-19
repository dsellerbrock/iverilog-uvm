module issue3317;
  wire a, b, c, d;
  assign (strong0, pull1) a = 1'b0;
  assign (highz0, strong1) a = 1'b1;
  assign (pull0, supply1) a = 1'bx;
  assign (pull0, supply1) b = 1'bx;
  assign (highz0, strong1) b = 1'b1;
  assign (strong0, pull1) b = 1'b0;

  assign (strong0, strong1) c = 1'b0;
  assign (supply0, highz1) c = 1'bx;
  assign (strong0, highz1) c = 1'bx;
  assign (strong0, highz1) d = 1'bx;
  assign (supply0, highz1) d = 1'bx;
  assign (strong0, strong1) d = 1'b0;

  // The opposite strong drivers are in separate branches of each resolver.
  logic drive0, drive1, drive_x, weak0_in, hiz_in;
  wire wide_a, wide_b;
  assign (strong0, pull1) wide_a = drive0;
  assign (weak0, weak1) wide_a = weak0_in;
  assign wide_a = hiz_in;
  assign (pull0, supply1) wide_a = drive_x;
  assign (highz0, strong1) wide_a = drive1;
  assign (highz0, strong1) wide_b = drive1;
  assign (pull0, supply1) wide_b = drive_x;
  assign wide_b = hiz_in;
  assign (weak0, weak1) wide_b = weak0_in;
  assign (strong0, pull1) wide_b = drive0;

  tri0 implicit_pull;
  assign (pull0, pull1) implicit_pull = 1'b1;
  assign (weak0, strong1) implicit_pull = 1'bx;

  // Figure 28-9 and a mixed known/ambiguous pair from the reproducer.
  wire two_ranges, mixed_pair, low_range, high_range;
  bufif1 (pull0, pull1) (two_ranges, 1'b1, 1'bx);
  bufif1 (weak0, weak1) (two_ranges, 1'b0, 1'bx);
  assign (strong0, strong1) mixed_pair = 1'b0;
  assign (supply0, highz1) mixed_pair = 1'bx;
  assign (strong0, highz1) low_range = 1'bx;
  assign (pull0, highz1) low_range = 1'bx;
  assign (highz0, strong1) high_range = 1'bx;
  assign (highz0, pull1) high_range = 1'bx;

  task automatic check(input string actual, expected);
    if (actual != expected)
      $fatal(1, "expected %s, got %s", expected, actual);
  endtask

  initial begin
    drive0 = 1'b0;
    drive1 = 1'b1;
    drive_x = 1'bx;
    weak0_in = 1'b0;
    hiz_in = 1'bz;
    #1;
    check($sformatf("%v %v %v %v / %b", a, b, c, d, {a,b,c,d}),
          "67X 67X 760 760 / xx00");
    check($sformatf("%v %v / %b", wide_a, wide_b, {wide_a,wide_b}),
          "67X 67X / xx");
    check($sformatf("%v %v %v %v %v / %b", implicit_pull, two_ranges,
                    mixed_pair, low_range, high_range,
                    {implicit_pull,two_ranges,mixed_pair,low_range,high_range}),
          "56X 35X 760 StL StH / xx0xx");

    drive0 = 1'bz;
    #1;
    check($sformatf("%v %v / %b", wide_a, wide_b, {wide_a,wide_b}),
          "761 761 / 11");
    drive0 = 1'b0;
    #1;
    check($sformatf("%v %v / %b", wide_a, wide_b, {wide_a,wide_b}),
          "67X 67X / xx");
    $display("PASSED");
  end
endmodule
