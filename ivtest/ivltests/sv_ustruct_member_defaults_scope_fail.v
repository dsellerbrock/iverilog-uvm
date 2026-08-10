package struct_default_leaf_pkg;
  localparam integer BASE = 10;

  typedef struct {
    integer value = BASE + 1;
  } leaf_t;
endpackage

package struct_default_scope_pkg;
  import struct_default_leaf_pkg::leaf_t;

  localparam integer BASE = 40;

  typedef struct {
    integer value = BASE + 2;
  } record_t;

  typedef struct {
    record_t record;
    integer tail = BASE + 3;
  } nested_t;

  typedef struct {
    leaf_t leaf;
    integer wrapper = BASE + 4;
  } cross_t;
endpackage

module struct_default_qualified_no_import(output logic passed);
  localparam integer BASE = 1000;
  struct_default_scope_pkg::record_t value;

  initial begin
    #0;
    passed = value.value == 42;
  end
endmodule

module struct_default_wildcard_import(output logic passed);
  import struct_default_scope_pkg::*;

  localparam integer BASE = 2000;
  record_t value;

  initial begin
    #0;
    passed = value.value == 42;
  end
endmodule

module struct_default_nested_same_package(output logic passed);
  localparam integer BASE = 3000;
  struct_default_scope_pkg::nested_t value;

  initial begin
    #0;
    passed = value.record.value == 42 && value.tail == 43;
  end
endmodule

module struct_default_nested_cross_package(output logic passed);
  localparam integer BASE = 4000;
  struct_default_scope_pkg::cross_t value;

  initial begin
    #0;
    passed = value.leaf.value == 11 && value.wrapper == 44;
  end
endmodule

module sv_ustruct_member_defaults_scope_fail;
  logic qualified_ok;
  logic wildcard_ok;
  logic nested_ok;
  logic cross_ok;

  struct_default_qualified_no_import qualified_test(qualified_ok);
  struct_default_wildcard_import wildcard_test(wildcard_ok);
  struct_default_nested_same_package nested_test(nested_ok);
  struct_default_nested_cross_package cross_test(cross_ok);

  initial begin
    #1;
    if (qualified_ok && wildcard_ok && nested_ok && cross_ok)
      $display("PASSED");
    else
      $display("FAILED qualified=%b wildcard=%b nested=%b cross=%b",
               qualified_ok, wildcard_ok, nested_ok, cross_ok);
    $finish(0);
  end
endmodule
