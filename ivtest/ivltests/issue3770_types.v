// A package cannot refer to declarations in its compilation-unit scope.
typedef logic [6:0] unit_word_t;
class UnitClass;
  typedef logic [4:0] nested_t;
  int field = 19;
endclass
function automatic logic [3:0] resolve_or(input logic [3:0] drivers[]);
  logic [3:0] value = 0;
  foreach (drivers[i]) value |= drivers[i];
  return value;
endfunction
nettype logic [3:0] unit_net_t with resolve_or;

package p;
  typedef unit_word_t unused_t;
  typedef $unit::unit_word_t qualified_t;
  UnitClass handle;
  typedef UnitClass::nested_t nested_t;
  unit_net_t unused_net;
  nettype unit_net_t alias_net_t;
  function int cast_word();
    return unit_word_t'(511);
  endfunction
  function int cast_nested();
    return $unit::UnitClass::nested_t'(511);
  endfunction
  class Box #(type T = int);
    T field;
  endclass
  Box#(UnitClass::nested_t) boxed;
endpackage

module test;
  import p::alias_net_t;
  alias_net_t bus;
  p::qualified_t word;
  p::nested_t nested_word;
  assign bus = 4'b0101;
  assign bus = 4'b1010;
  initial begin
    p::handle = new;
    p::boxed = new;
    #1;
    if ($bits(word) != 7 || $bits(nested_word) != 5 ||
        $bits(p::boxed.field) != 5 ||
        p::handle.field != 19 || bus !== 4'b1111 ||
        p::cast_word() != 127 || p::cast_nested() != 31)
      $fatal(1, "Incorrect binding");
    $display("PASSED");
  end
endmodule
