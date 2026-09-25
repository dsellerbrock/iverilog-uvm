// IEEE 1800-2017/2023: a package may qualify its own prior typedef.
package self_type_pkg;
  typedef logic [7:0] word_t;

  class probe;
    self_type_pkg::word_t prop;

    function self_type_pkg::word_t copy(input self_type_pkg::word_t value);
      return value;
    endfunction
  endclass
endpackage

// Escaped package names retain their required terminating whitespace.
package \self_escaped_pkg ;
  typedef logic [5:0] word_t;
  class probe;
    \self_escaped_pkg /* scoped comment */ ::word_t prop;
  endclass
endpackage

// A nearer class with the package's name wins for type lookup.
package self_shadow_pkg;
  typedef logic [7:0] word_t;
  class self_shadow_pkg;
    typedef logic [3:0] word_t;
  endclass
  class probe;
    self_shadow_pkg::word_t prop;
  endclass
endpackage

// An inherited typedef with the package name is nearer than the package.
package self_inherited_pkg;
  typedef logic [7:0] word_t;
  class narrow;
    typedef logic [3:0] word_t;
  endclass
  class base;
    typedef narrow self_inherited_pkg;
  endclass
  class derived extends base;
    self_inherited_pkg::word_t prop;
  endclass
endpackage

// An explicitly imported same-name class also takes precedence.
package self_import_donor_pkg;
  class self_import_pkg;
    typedef logic [3:0] word_t;
  endclass
endpackage

package self_import_pkg;
  import self_import_donor_pkg::self_import_pkg;
  typedef logic [7:0] word_t;
  class probe;
    self_import_pkg::word_t prop;
  endclass
endpackage

module main;
  self_type_pkg::probe obj;
  self_shadow_pkg::probe shadow;
  self_import_pkg::probe imported_shadow;
  self_inherited_pkg::derived inherited_shadow;
  \self_escaped_pkg ::probe escaped_obj;

  initial begin
    obj = new;
    shadow = new;
    imported_shadow = new;
    inherited_shadow = new;
    escaped_obj = new;
    obj.prop = 8'h5a;
    if ($bits(obj.prop) != 8 || obj.copy(obj.prop) !== 8'h5a)
      $fatal(1, "self-qualified package typedef failed");
    if ($bits(shadow.prop) != 4)
      $fatal(1, "nearer class type was hidden by package lookup");
    if ($bits(imported_shadow.prop) != 4)
      $fatal(1, "imported class type was hidden by package lookup");
    if ($bits(inherited_shadow.prop) != 4)
      $fatal(1, "inherited class type was hidden by package lookup");
    if ($bits(escaped_obj.prop) != 6)
      $fatal(1, "escaped package typedef was not resolved");
    $display("PASSED");
  end
endmodule
