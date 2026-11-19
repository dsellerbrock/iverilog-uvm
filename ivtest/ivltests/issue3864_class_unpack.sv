// IEEE 1800-2017/2023 11.4.14.1–11.4.14.3.
class issue3864_packet;
  logic [7:0] first, second;
endclass

typedef struct {
  bit [3:0] tag;
  logic [3:0] coords [1:2];
} issue3864_aggregate;

class issue3864_base;
  protected logic [3:0] header;

  function void unpack(issue3864_base target);
    {>>{target}} = 32'h12345678;
  endfunction

  function logic [3:0] get_header();
    return header;
  endfunction
endclass

class issue3864_derived extends issue3864_base;
  logic [7:0] samples [3:2];
  issue3864_aggregate data;
endclass

class issue3864_tree;
  logic [3:0] head;
  issue3864_packet live, absent;
  issue3864_packet slots [5:4];
  logic [3:0] tail;
endclass

class issue3864_mixed;
  bit [1:0] two_state;
  logic [3:0] four_state;
endclass

typedef struct packed {
  bit [1:0] two_state;
  logic [1:0] four_state;
} issue3864_packed_pair;

class issue3864_packed_peer;
  issue3864_packed_pair data;
endclass

typedef struct { logic [3:0] shared, a; } issue3864_view_a;
typedef struct { logic [3:0] shared, b; } issue3864_view_b;
typedef union {
  issue3864_view_a first;
  issue3864_view_b second;
} issue3864_overlay;

class issue3864_fixed;
  logic [3:0] words [2:1][4:5];
  issue3864_overlay overlay;
endclass

module issue3864_class_unpack;
  issue3864_packet p, alias_p, none, replacement;
  issue3864_packet fixed_slots [2:1];
  issue3864_packet dynamic_slots[];
  issue3864_base base_view;
  issue3864_derived derived_obj;
  issue3864_tree tree;
  issue3864_mixed mixed;
  issue3864_packed_peer packed_peer;
  issue3864_fixed fixed_obj;
  logic [3:0] left_peer, right_peer;
  int index_calls;

  function automatic int slot_index();
    index_calls++;
    return 4;
  endfunction

  function automatic int replace_slots();
    dynamic_slots = new[1];
    dynamic_slots[0] = replacement;
    return 0;
  endfunction

  initial begin
    p = new;
    alias_p = p;
    {>>{p}} = 16'h1234;
    if (p.first !== 8'h12 || p.second !== 8'h34 || p != alias_p)
      $fatal(1, "class unpack of 16'h1234 did not update the original object");

    derived_obj = new;
    base_view = derived_obj;
    base_view.unpack(base_view);
    if (base_view.get_header() !== 4'h1 ||
        derived_obj.samples[3] !== 8'h23 || derived_obj.samples[2] !== 8'h45 ||
        derived_obj.data.tag !== 4'h6 ||
        derived_obj.data.coords[1] !== 4'h7 || derived_obj.data.coords[2] !== 4'h8)
      $fatal(1, "live derived layout, protected base property, or fixed aggregate order");

    tree = new;
    tree.live = p;
    tree.slots[4] = p;
    // The same object appears twice. Both occurrences consume bits.
    // The two null children consume nothing and remain null.
    {>>{tree}} = 40'ha01020304b;
    if (tree.head !== 4'ha || tree.tail !== 4'hb ||
        tree.absent != null || tree.slots[5] != null ||
        tree.live != alias_p || tree.slots[4] != alias_p ||
        alias_p.first !== 8'h03 || alias_p.second !== 8'h04)
      $fatal(1, "nested aliases, null children, or fixed handle slots");

    {>>{left_peer, none, tree.live, right_peer}} = 28'h5cafe7f;
    if ({left_peer, p.first, p.second, right_peer} !== 24'h5cafe7 || none != null)
      $fatal(1, "selected class property between vector peers");

    {>>{tree.head[2:1], tree.live, tree.tail}} = 22'b11_0101_0110_0111_1000_0011;
    if (tree.head !== 4'he || {p.first, p.second} !== 16'h5678 || tree.tail !== 4'h3)
      $fatal(1, "packed property peers");

    packed_peer = new;
    {>>{packed_peer.data.two_state, p, packed_peer.data.four_state}} = 20'bxz_0001_0010_0011_0100_xz;
    if (packed_peer.data !== 4'b00xz || {p.first, p.second} !== 16'h1234)
      $fatal(1, "two-state packed property peer conversion");

    {>>{tree.slots[slot_index()]}} = 16'h4567;
    if (index_calls != 1 || {p.first, p.second} !== 16'h4567)
      $fatal(1, "indexed class property selection");

    fixed_slots[1] = alias_p;
    dynamic_slots = new[2];
    dynamic_slots[1] = alias_p;
    {>>{fixed_slots[2], fixed_slots[1], dynamic_slots[0], dynamic_slots[1]}} = 32'h89abcdef;
    if ({p.first, p.second} !== 16'hcdef ||
        fixed_slots[2] != null || dynamic_slots[0] != null ||
        fixed_slots[1] != alias_p || dynamic_slots[1] != alias_p)
      $fatal(1, "fixed or dynamic indexed class handle selection");

    replacement = new;
    {>>{dynamic_slots[1], dynamic_slots[replace_slots()]}} = 32'h12ab34cd;
    if (dynamic_slots.size() != 1 || dynamic_slots[0] != replacement ||
        {p.first, p.second, replacement.first, replacement.second} !== 32'h12ab34cd)
      $fatal(1, "an earlier captured receiver was retargeted by a later selector");

    fixed_obj = new;
    fixed_obj.overlay.second = '{4'he, 4'hf};
    {>>{fixed_obj}} = 24'h123456;
    if (fixed_obj.words[2][4] !== 4'h1 || fixed_obj.words[2][5] !== 4'h2 ||
        fixed_obj.words[1][4] !== 4'h3 || fixed_obj.words[1][5] !== 4'h4 ||
        fixed_obj.overlay.first.a !== 4'h6 || fixed_obj.overlay.second.shared !== 4'h5)
      $fatal(1, "multidimensional order or first declared union member");

    mixed = new;
    {<<4{mixed}} = 8'b01011100;
    if ({mixed.two_state, mixed.four_state} !== 6'b110101)
      $fatal(1, "consume six leading bits before applying the inverse slice permutation");
    {<<4{left_peer, mixed, none, right_peer}} = 16'b1010_0011_0110_0100;
    if ({left_peer, mixed.two_state, mixed.four_state, right_peer} !== 14'b0101_10_0011_1010)
      $fatal(1, "inverse block permutation crossed fixed and class target boundaries");
    {>>{mixed}} = 6'bxz_x1z0;
    if (mixed.two_state !== 2'b00 || mixed.four_state !== 4'bx1z0)
      $fatal(1, "2-state and 4-state leaf conversion");

    $display("PASSED");
  end
endmodule
