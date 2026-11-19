module issue3896_concat_leaves;
  logic [2:0] high;
  bit [1:0] two_state;
  logic low;
  logic [5:0] mixed = 6'bxz1_1z_0;
  logic signed [1:0] short_rhs = 2'b10;
  wire [5:0] bus = 6'b101010;
  logic [5:0] bus_rhs = 6'b111001;
  logic [1:0] replacement = 2'b11;
  wire [3:0] clipped = 4'b1000;
  logic [2:0] words [0:1];
  logic [9:0] clipped_rhs = 10'b1_101_011_000;
  bit [1:0] replacement_assign = 2'b01;
  bit two_a;
  bit [1:0] two_b;
  logic [3:0] all_two_rhs = 4'b1_xz1;
  logic [3:0] ignored_rhs = 4'b1000;
  bit [1:0] two_state_rhs = 2'b10;
  typedef struct { bit [1:0] value; } box_t;
  box_t box;
  logic [1:0] box_rhs = 2'b1x;

  task automatic activate_signed_force;
    force {high, low} = short_rhs;
  endtask

  initial begin
    #1;
    force {high, {two_state, low}} = {mixed[5:2], mixed[1:0]};
    if ({high, two_state, low} !== 6'bxz1_10_0)
      $fatal(1, "Initial nested force and two-state conversion");
    mixed = 6'bz0x_x1_1;
    #1;
    if ({high, two_state, low} !== 6'bz0x_01_1)
      $fatal(1, "Live nested force and two-state conversion");
    release {high, {two_state, low}};

    activate_signed_force();
    if ({high, low} !== 4'b1110) $fatal(1, "Initial sign extension");
    short_rhs = 2'b01;
    #1;
    if ({high, low} !== 4'b0001) $fatal(1, "Live sign extension after task");
    release {high, low};

    force {bus[5:3], bus[2:0]} = bus_rhs;
    if (bus !== 6'b111001) $fatal(1, "Initial disjoint net slices");
    release bus[1:0];
    if (bus !== 6'b111010) $fatal(1, "Release of part of one leaf");
    bus_rhs = 6'b010101;
    #1;
    if (bus !== 6'b010110) $fatal(1, "Both surviving ranges must stay live");
    force bus[4:3] = replacement;
    if (bus !== 6'b011110) $fatal(1, "Initial overlapping force");
    bus_rhs = 6'b110101;
    replacement = 2'b00;
    #1;
    if (bus !== 6'b100110) $fatal(1, "Replacement and both surviving ranges");
    release {bus[5:3], bus[2:0]};
    if (bus !== 6'b101010) $fatal(1, "Release of both leaves");

    // The rightmost word is discarded and the low bit of [1:-1] is clipped.
    force {low, clipped[1:-1], words[0], words[3]} = clipped_rhs;
    if ({low, clipped, words[0]} !== 8'b1_1010_011)
      $fatal(1, "Initial ignored, clipped and compact-array leaves");
    clipped_rhs = 10'b0_011_101_111;
    #1;
    if ({low, clipped, words[0]} !== 8'b0_1001_101)
      $fatal(1, "Live ignored, clipped and compact-array leaves");
    release {low, clipped[1:-1], words[0], words[3]};
    low = 1;
    words[0] = 3'b110;
    if ({low, clipped, words[0]} !== 8'b1_1000_110)
      $fatal(1, "Release must continue after an ignored leaf");

    // Use a source-level RHS concat as well as the compiler's descriptor.
    mixed = 6'bxz1_1z_0;
    assign {high, {two_state, low}} = {mixed[5:1], mixed[0]};
    if ({high, two_state, low} !== 6'bxz1_10_0)
      $fatal(1, "Initial assign preserves X/Z only in four-state leaves");
    // The full RHS publishes a change even though the converted slices
    // return to the values that the structural source held before assign.
    mixed = 6'bz0x_z1_1;
    #1;
    if ({high, two_state, low} !== 6'bz0x_01_1)
      $fatal(1, "Live slices after a same-slot RHS change");
    assign two_state = replacement_assign;
    mixed = 6'b1zx_x0_0;
    replacement_assign = 2'b11;
    #1;
    if ({high, two_state, low} !== 6'b1zx_11_0)
      $fatal(1, "Replacement assign must preserve both sibling links");
    deassign {high, {two_state, low}};
    mixed = '0;
    replacement_assign = '0;
    #1;
    if ({high, two_state, low} !== 6'b1zx_11_0)
      $fatal(1, "Deassign all three members");

    assign {two_a, two_b} = all_two_rhs;
    if ({two_a, two_b} !== 3'b001) $fatal(1, "Initial truncated 2-state value");
    all_two_rhs = 4'b0_1zx;
    #1;
    if ({two_a, two_b} !== 3'b100) $fatal(1, "Live truncated 2-state value");
    deassign {two_a, two_b};

    assign {low, words[3]} = ignored_rhs;
    if (low !== 1'b1) $fatal(1, "Assign must continue after an ignored leaf");
    deassign {low, words[3]};
    low = 0;
    ignored_rhs = 4'b1111;
    #1;
    if (low !== 1'b0) $fatal(1, "Deassign must continue after an ignored leaf");

    assign {low, two_b} = two_state_rhs[1:-1];
    if ({low, two_b} !== 3'b100) $fatal(1, "Initial clipped RHS conversion");
    two_state_rhs = 2'b01;
    #1;
    if ({low, two_b} !== 3'b010) $fatal(1, "Live clipped RHS conversion");
    deassign {low, two_b};

    force {box.value} = box_rhs;
    if (box.value !== 2'b10) $fatal(1, "Initial force of a struct member");
    box_rhs = 2'bz1;
    #1;
    if (box.value !== 2'b01) $fatal(1, "Live force of a struct member");
    release {box.value};

    begin : force_reducer
      reg a, b;
      reg [1:0] rhs;
      rhs = 2'b11;
      #1 force {a, b} = rhs;
      $display("%b", {a, b});
      rhs = 2'b01;
      #1 $display("%b", {a, b});
      rhs = 2'b00;
      #1 $display("%b", {a, b});
      release {a, b};
    end

    begin : assign_reducer
      reg a, b;
      reg [1:0] rhs;
      rhs = 2'b10;
      #1 assign {a, b} = rhs;
      if ({a, b} !== 2'b10) $fatal(1, "Initial assign");
      rhs = 2'b01;
      #1 $display("%b", {a, b});
      deassign {a, b};
      rhs = 2'b10;
      #1 $display("%b", {a, b});
    end

    $display("PASSED");
  end
endmodule
