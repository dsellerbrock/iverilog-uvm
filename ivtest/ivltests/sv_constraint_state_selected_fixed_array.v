// IEEE 1800-2017 18.3, 18.5, 18.5.8.1 and 7.4.6;
// IEEE 1800-2023 18.3, 18.5, 18.5.7.1 and 7.4.5.
class state_selected_fixed_array;
  int selector;
  int force_bad;
  rand int values[2:3][5:3];

  constraint selected_row {
    foreach (values[,j]) values[selector][j] == selector * 100 + j;
    values[2][5] == 205;
  }
  constraint conflicting_row { force_bad -> values[selector][4] == -1; }
endclass

class state_selected_fixed_array_oob;
  int selector;
  bit guard;
  rand bit [7:0] values[2:3];

  // 7.4.6 Table 7-1: an invalid read of a 2-state integral element is '0.
  constraint default_read { values[selector] == 8'h00; }
  // The invalid read remains inside an inactive implication branch.
  constraint guarded_read { guard -> values[selector] == 8'hff; }
endclass

class state_selected_fixed_array_state_int_oob;
  int selector;
  int values[2:3];
  rand bit witness;

  // A non-rand int array remains a declared two-state array; its invalid
  // state-selected read is zero independently of solver variable encoding.
  constraint default_read { values[selector] == 0; witness == 1; }
endclass

class state_selected_fixed_array_state_integer;
  int selector;
  integer values[2:3];
  rand bit witness;

  constraint selected_read { values[selector] == 7; witness == 1; }
endclass

class state_selected_fixed_array_wide_bit;
  int selector;
  bit [127:0] values[2:3];
  rand bit witness;

  constraint selected_read {
    values[selector] == {64'h8000000000000001, 64'hfedcba9876543210};
    witness == 1;
  }
endclass

class state_selected_fixed_array_wide_logic;
  int selector;
  logic [127:0] values[2:3];
  rand bit witness;

  constraint selected_read {
    values[selector] == {64'hfedcba9876543210, 64'h8000000000000001};
    witness == 1;
  }
endclass

class state_selected_fixed_array_random_selector;
  rand int selector;
  int forced;
  bit guard;
  integer values[2:3];
  rand bit witness;

  constraint selected_read {
    forced != 0 -> selector == forced;
    guard -> values[selector] == 7;
    witness == 1;
  }
endclass

class state_selected_fixed_array_logic_sifting;
  rand int selector;
  int mode;
  bit control;
  integer values[2:3];
  rand bit witness;

  constraint force_selector { selector == 3; witness == 1; }
  constraint logical_reads {
    mode == 1 -> ((values[selector] == 7) && (values[selector] == 7));
    mode == 2 -> ((values[selector] == 0) || (values[selector] == 0));
    mode == 3 -> !(control && (values[selector] == 7));
    mode == 4 -> (control || (values[selector] == 0));
  }
endclass

class state_selected_fixed_array_xz_selector;
  logic signed [31:0] selector;
  bit guard;
  integer values[2:3];
  rand bit witness;

  constraint guarded_read { guard -> values[selector] == 7; witness == 1; }
endclass

class state_selected_fixed_array_oob4_active;
  int selector;
  rand logic signed [31:0] values[2:3];
  constraint invalid_read { values[selector] == 0; }
endclass

class state_selected_fixed_array_oob4_guarded;
  int selector;
  bit guard;
  rand integer values[2:3];
  constraint invalid_read { guard -> values[selector] == 0; }
  constraint invalid_if { if (guard) values[selector] == 1; }
endclass

module test;
  state_selected_fixed_array obj;
  state_selected_fixed_array_oob oob;
  state_selected_fixed_array_state_int_oob state_int_oob;
  state_selected_fixed_array_state_integer state_integer;
  state_selected_fixed_array_wide_bit wide_bit;
  state_selected_fixed_array_wide_logic wide_logic;
  state_selected_fixed_array_random_selector random_selector;
  state_selected_fixed_array_logic_sifting logic_sifting;
  state_selected_fixed_array_xz_selector xz_selector;
  state_selected_fixed_array_oob4_active oob4_active;
  state_selected_fixed_array_oob4_guarded oob4_guarded;
  int saved;

  initial begin
    obj = new;
    obj.force_bad = 0;
    obj.selector = 2;
    if (!obj.randomize()) $fatal(1, "selector 2 should satisfy its row");
    if (obj.values[2][5] != 205 || obj.values[2][4] != 204
        || obj.values[2][3] != 203)
      $fatal(1, "selector 2 did not constrain the ascending nonzero row");

    obj.selector = 3;
    if (!obj.randomize()) $fatal(1, "selector 3 should satisfy its row");
    if (obj.values[3][5] != 305 || obj.values[3][4] != 304
        || obj.values[3][3] != 303 || obj.values[2][5] != 205)
      $fatal(1, "selector change or constant-index neighbor was lost");

    saved = obj.values[3][4];
    obj.force_bad = 1;
    if (obj.randomize())
      $fatal(1, "contradictory selected constraint succeeded");
    if (obj.values[3][4] != saved)
      $fatal(1, "failed selected constraint changed the array");

    oob = new;
    oob.selector = 99;
    oob.guard = 0;
    if (!oob.randomize())
      $fatal(1, "2-state invalid selected read should use its zero default");

    state_int_oob = new;
    state_int_oob.selector = 99;
    if (!state_int_oob.randomize() || state_int_oob.witness != 1)
      $fatal(1, "non-rand int invalid selected read should use zero");

    state_integer = new;
    state_integer.values[2] = 7;
    state_integer.values[3] = 'x;
    state_integer.selector = 2;
    if (!state_integer.randomize() || state_integer.witness != 1)
      $fatal(1, "unselected X state element caused an error");
    state_integer.selector = 3;
    if (state_integer.randomize())
      $fatal(1, "selected X state element did not cause an error");

    wide_bit = new;
    wide_bit.selector = 2;
    wide_bit.values[2] = 128'h8000000000000001_fedcba9876543210;
    if (!wide_bit.randomize() || wide_bit.witness != 1)
      $fatal(1, "known 128-bit bit state element was truncated");

    wide_logic = new;
    wide_logic.selector = 3;
    wide_logic.values[3] = 128'hfedcba9876543210_8000000000000001;
    if (!wide_logic.randomize() || wide_logic.witness != 1)
      $fatal(1, "known 128-bit logic state element was rejected or truncated");

    random_selector = new;
    random_selector.values[2] = 7;
    random_selector.values[3] = 'x;
    random_selector.forced = 2;
    random_selector.guard = 1;
    if (!random_selector.randomize() || random_selector.selector != 2
        || random_selector.witness != 1)
      $fatal(1, "random selector could not select the known state element");
    random_selector.forced = 3;
    if (random_selector.randomize())
      $fatal(1, "random selector silently selected an X state element");
    if (random_selector.selector != 2)
      $fatal(1, "selected-X evaluation error did not roll back selector");
    random_selector.guard = 0;
    if (!random_selector.randomize() || random_selector.selector != 3)
      $fatal(1, "inactive random-selector X state read was not sifted");
    random_selector.guard = 1;
    random_selector.forced = 99;
    if (random_selector.randomize())
      $fatal(1, "random selector silently selected an invalid index");
    if (random_selector.selector != 3)
      $fatal(1, "invalid-index evaluation error did not roll back selector");

    logic_sifting = new;
    logic_sifting.values[3] = 'x;
    logic_sifting.mode = 1;
    if (logic_sifting.randomize())
      $fatal(1, "two erroneous AND operands mutually sifted their errors");
    logic_sifting.mode = 2;
    if (logic_sifting.randomize())
      $fatal(1, "two erroneous OR operands mutually sifted their errors");
    logic_sifting.control = 0;
    logic_sifting.mode = 3;
    if (!logic_sifting.randomize() || logic_sifting.witness != 1)
      $fatal(1, "known false AND operand did not sift the erroneous read");
    logic_sifting.control = 1;
    logic_sifting.mode = 4;
    if (!logic_sifting.randomize() || logic_sifting.witness != 1)
      $fatal(1, "known true OR operand did not sift the erroneous read");

    xz_selector = new;
    xz_selector.values[2] = 7;
    xz_selector.selector = 'x;
    xz_selector.guard = 0;
    if (!xz_selector.randomize() || xz_selector.witness != 1)
      $fatal(1, "inactive X selector was not sifted");
    xz_selector.guard = 1;
    if (xz_selector.randomize())
      $fatal(1, "active X selector did not cause an error");
    xz_selector.selector = 'z;
    xz_selector.guard = 0;
    if (!xz_selector.randomize())
      $fatal(1, "inactive Z selector was not sifted");
    xz_selector.guard = 1;
    if (xz_selector.randomize())
      $fatal(1, "active Z selector did not cause an error");

    oob4_active = new;
    oob4_active.selector = 99;
    oob4_active.values[2] = 77;
    if (oob4_active.randomize())
      $fatal(1, "4-state invalid selected read should fail an active constraint");
    if (oob4_active.values[2] != 77)
      $fatal(1, "4-state evaluation error changed the array");

    oob4_guarded = new;
    oob4_guarded.selector = 99;
    oob4_guarded.guard = 0;
    if (!oob4_guarded.randomize())
      $fatal(1, "inactive 4-state invalid selected read should be sifted");
    saved = oob4_guarded.values[2];
    oob4_guarded.guard = 1;
    if (oob4_guarded.randomize())
      $fatal(1, "active integer invalid selected read should fail");
    if (oob4_guarded.values[2] != saved)
      $fatal(1, "guarded evaluation error changed the array");
    $display("PASSED");
  end
endmodule
