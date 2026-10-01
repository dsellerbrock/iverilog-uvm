// Typedef-only concrete specializations register once; an unelaborated
// generate branch and the generic master do not register.
package registry_pkg;
  int registrations[string];
  class registry #(type T = int, string Name = "unnamed");
    static registry #(T, Name) me = get();
    static function registry #(T, Name) get();
      if (me == null) begin
        me = new;
        registrations[Name]++;
      end
      return me;
    endfunction
  endclass
  class base_test #(type T = int, string Name = "generic");
    typedef registry #(base_test #(T, Name), Name) type_id;
    static function type_id get_type(); return type_id::get(); endfunction
  endclass
  typedef base_test #(byte, "package") package_test_t;
endpackage

module test;
  import registry_pkg::*;
  typedef base_test #(shortint, "module") module_test_t;
  if (1) begin : enabled
    typedef base_test #(bit, "generate") generated_test_t;
    typedef base_test #(bit, "generate") duplicate_alias_t;
  end
  if (0) begin : disabled
    typedef base_test #(longint, "disabled") disabled_test_t;
  end
  typedef base_test #(integer, "used") used_test_t;
  used_test_t used_handle;
  initial begin
    #1;
    if (registrations["package"] == 1 && registrations["module"] == 1 &&
        registrations["generate"] == 1 && registrations["used"] == 1 &&
        registrations["disabled"] == 0 && registrations["generic"] == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED package=%0d module=%0d generate=%0d used=%0d disabled=%0d generic=%0d",
        registrations["package"], registrations["module"],
        registrations["generate"], registrations["used"],
        registrations["disabled"], registrations["generic"]);
  end
endmodule
