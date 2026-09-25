// IEEE 1800-2017 8.25: equal effective values of one parameterized class
// denote one specialization across positional, named and defaulted actuals.
class mv_root;
endclass

class mv_box #(int HostWidth = 32, int DeviceWidth = HostWidth)
    extends mv_root;
  static int count;
  function new;
    count++;
  endfunction
endclass

class mv_string #(string Name = "left", int Width = 32) extends mv_root;
endclass

class mv_packed #(int Width = 16, logic [15:0] Value = 0)
    extends mv_root;
endclass

class mv_type #(type T = int, int Width = 32) extends mv_root;
endclass

class mv_other #(int HostWidth = 32, int DeviceWidth = HostWidth)
    extends mv_root;
endclass

module sv_class_multi_value_identity_2017;
  mv_box#(32, 33) positional;
  mv_box#(.DeviceWidth(33), .HostWidth(32)) named;
  mv_box#(.DeviceWidth(33)) defaulted;
  mv_box#(32, 34) unequal;
  mv_box#(33, 33) dependent_positional;
  mv_box#(33) dependent_default;
  mv_string#("left", 32) string_equal;
  mv_string#(.Width(32), .Name("left")) string_named;
  mv_string#("right", 32) string_unequal;
  mv_packed#(16, 16'h00ff) packed_positional;
  mv_packed#(.Value(16'h00ff), .Width(16)) packed_named;
  mv_packed#(16, 16'h01ff) packed_unequal;
  mv_type#(int, 32) type_int;
  mv_type#(bit, 32) type_bit;
  mv_other#(32, 33) other_owner;
  mv_root candidate;
  initial begin
    positional = new;
    candidate = positional;
    if (!$cast(named, candidate) || !$cast(defaulted, candidate))
      $fatal(1, "equal effective values have distinct class identity");
    if ($cast(unequal, candidate))
      $fatal(1, "unequal effective values share class identity");
    named = new;
    defaulted = new;
    if (mv_box#(32,33)::count != 3)
      $fatal(1, "equal effective values have distinct static identity");
    dependent_positional = new;
    candidate = dependent_positional;
    if (!$cast(dependent_default, candidate))
      $fatal(1, "dependent default has distinct class identity");
    dependent_default = new;
    if (mv_box#(33,33)::count != 2)
      $fatal(1, "dependent default has distinct static identity");
    string_equal = new;
    candidate = string_equal;
    if (!$cast(string_named, candidate) || $cast(string_unequal, candidate))
      $fatal(1, "string actuals have wrong class identity");
    packed_positional = new;
    candidate = packed_positional;
    if (!$cast(packed_named, candidate) || $cast(packed_unequal, candidate))
      $fatal(1, "packed values have wrong class identity");
    type_int = new;
    candidate = type_int;
    if ($cast(type_bit, candidate))
      $fatal(1, "distinct type actuals share class identity");
    candidate = positional;
    if ($cast(other_owner, candidate))
      $fatal(1, "distinct declarations share class identity");
    $display("PASSED");
  end
endmodule
