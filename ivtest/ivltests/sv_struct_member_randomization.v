// IEEE 1800-2017 18.4: random qualifiers on members of an unpacked
// structure are semantic.  An outer rand property activates those members;
// an unqualified neighbour remains ordinary state and randc retains its
// cycle history.
typedef struct {
  rand bit [7:0] changing;
  bit [7:0] held;
  randc bit [1:0] cycling[2];
} member_random_record_t;

class member_random_item;
  rand member_random_record_t record;
endclass

module test;
  initial begin
    member_random_item item;
    bit seen[2][4];
    bit changing_moved;

    item = new;
    item.srandom(32'h21f0_1804);
    item.record.changing = 8'h00;
    item.record.held = 8'ha5;
    item.record.cycling[0] = 2'd0;
    item.record.cycling[1] = 2'd0;

    for (int draw = 0; draw < 4; draw++) begin
      if (item.randomize() !== 1)
        $fatal(1, "unpacked-struct member randomization failed");
      if (item.record.held !== 8'ha5)
        $fatal(1, "unqualified unpacked-struct member changed");
      for (int lane = 0; lane < 2; lane++) begin
        if (seen[lane][item.record.cycling[lane]])
          $fatal(1, "randc unpacked-struct member repeated within a cycle");
        seen[lane][item.record.cycling[lane]] = 1'b1;
      end
      if (item.record.changing != 8'h00)
        changing_moved = 1'b1;
    end

    for (int lane = 0; lane < 2; lane++)
      for (int value = 0; value < 4; value++)
        if (!seen[lane][value])
          $fatal(1, "randc unpacked-struct member missed a cycle value");

    repeat (12) begin
      if (item.randomize() !== 1)
        $fatal(1, "subsequent unpacked-struct randomization failed");
      if (item.record.held !== 8'ha5)
        $fatal(1, "unqualified unpacked-struct member changed");
      if (item.record.changing != 8'h00)
        changing_moved = 1'b1;
    end
    if (!changing_moved)
      $fatal(1, "rand unpacked-struct member never changed");

    $display("PASSED");
  end
endmodule
