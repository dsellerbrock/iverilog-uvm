package sv_ustruct_member_defaults_bad_pkg;
  integer runtime_value = 3;

  // The typedef is intentionally unused. Its member declaration is still
  // illegal: a variable is not a constant expression.
  typedef struct {
    integer value = runtime_value;
  } unused_pkg_t;
endpackage

module sv_ustruct_member_defaults_declaration_fail;
  integer runtime_value = 5;

  // An unused module typedef must be checked at its declaration.
  typedef struct {
    integer value = runtime_value;
  } unused_module_t;

  // A whole-variable initializer suppresses application of the member
  // default, but it does not make the member declaration legal.
  struct {
    integer value = runtime_value;
  } inline_overridden = '{17};

  class holder;
    static integer runtime_value = 7;

    // Class-local unused typedefs have the same declaration-time rule.
    typedef struct {
      integer value = runtime_value;
    } unused_class_t;
  endclass

  holder object_handle;

  function automatic integer unused_function;
    typedef struct {
      integer value = runtime_value;
    } unused_function_t;
    begin : named_scope
      typedef struct {
        integer value = runtime_value;
      } unused_block_t;
    end
    unused_function = 0;
  endfunction

  task automatic unused_task;
    typedef struct {
      integer value = runtime_value;
    } unused_task_t;
  endtask

  if (1) begin : generated_scope
    typedef struct {
      integer value = runtime_value;
    } unused_generate_t;
  end
endmodule
