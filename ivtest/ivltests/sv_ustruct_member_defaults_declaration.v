package sv_ustruct_member_defaults_valid_pkg;
  localparam integer PACKAGE_DEFAULT = 19;
  typedef struct {
    integer value = PACKAGE_DEFAULT;
  } unused_pkg_t;
endpackage

module sv_ustruct_member_defaults_declaration;
  localparam integer DEFAULT_VALUE = 7;

  typedef struct {
    integer value = DEFAULT_VALUE;
  } unused_valid_t;

  typedef struct {
    integer value = DEFAULT_VALUE;
  } record_t;

  record_t implicit_value;

  // The legal declaration is checked, while the explicit whole initializer
  // remains the value that is applied to this particular variable.
  struct {
    integer value = DEFAULT_VALUE;
  } inline_overridden = '{12};

  class holder;
    typedef struct {
      integer value = 23;
    } unused_class_t;
  endclass

  holder object_handle;

  initial begin
    if (implicit_value.value == DEFAULT_VALUE &&
        inline_overridden.value == 12)
      $display("PASSED");
    else
      $display("FAILED implicit=%0d overridden=%0d",
               implicit_value.value, inline_overridden.value);
    $finish(0);
  end
endmodule
