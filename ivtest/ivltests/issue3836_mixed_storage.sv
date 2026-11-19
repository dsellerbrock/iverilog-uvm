module issue3836_mixed_storage;
  logic [3:0] m[0:1];
  logic a = 0, b = 0;
  assign m[0][0] = a;
  // This dependency keeps the two structural drivers on a resolver.
  assign m[0][1] = m[0][0] ? b : 1'b1;
  wire [3:0] observed = m[0] ^ 4'b0011;

  logic [7:0] packed_only;
  logic source = 1;
  assign packed_only[0] = source;
  wire [7:0] packed_observed = packed_only;

  logic [3:0] delayed;
  assign #2 delayed[0] = source;
  assign delayed[1] = delayed[0];

  bit [3:0] two_state[0:1];
  assign two_state[0][0] = source;
  wire [1:0] net_control;
  uwire [1:0] uwire_control;
  assign net_control[0] = source;
  assign uwire_control[0] = source;

  initial begin
    #1;
    m[0][2] = 1;
    #1 a = 1;
    #1;
    if (m[0] !== 4'bx101 || observed !== 4'bx110)
      $fatal(1, "source change lost procedural storage: m[0]=%b, observed=%b",
             m[0], observed);

    m[0][2] = 1'bz;
    b = 1'bz;
    #1;
    if (m[0] !== 4'bxzz1)
      $fatal(1, "explicit procedural or continuous Z lost: %b", m[0]);
    a = 0;
    #1;
    if (m[0] !== 4'bxz10)
      $fatal(1, "procedural Z lost on later source change: %b", m[0]);

    if (m[1] !== 4'bxxxx || two_state[1] !== 4'b0000)
      $fatal(1, "undriven words started at %b and %b", m[1], two_state[1]);
    m[1][1] = 0;
    two_state[1][2] = 1;
    two_state[0][2] = 1;
    #1;
    if (m[1] !== 4'bxx0x || two_state[1] !== 4'b0100 || two_state[0] !== 4'b0101)
      $fatal(1, "incorrect values after stores: %b %b %b", m[1], two_state[1], two_state[0]);
    if (net_control !== 2'bz1 || uwire_control !== 2'bz1)
      $fatal(1, "explicit nets lost high impedance: %b %b", net_control, uwire_control);
    if (packed_observed !== 8'bxxxxxxx1)
      $fatal(1, "packed observer saw %b", packed_observed);
    $display("%b %b", 8'b0, packed_observed);

    // A force on a continuously assigned variable overlays its storage.
    force packed_only = 8'hff;
    delayed[2] <= 1;
    source = 0;
    #1;
    if (packed_observed !== 8'hff || delayed !== 4'bx111 || two_state[0] !== 4'b0100)
      $fatal(1, "incorrect force, delay or two-state update: %b %b %b",
             packed_observed, delayed, two_state[0]);
    release packed_only;
    #2;
    if (packed_observed !== 8'bxxxxxxx0 || delayed !== 4'bx100)
      $fatal(1, "incorrect value after release or delay: %b %b", packed_observed, delayed);
    $display("PASSED");
  end
endmodule
