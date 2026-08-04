// An out-of-block method of a derived class can use an inherited enum
// literal without qualifying it through the base class (IEEE 1800-2017 8.3).
package inherited_enum_pkg;
  class enum_base;
    typedef enum int { NEVER, STARTED, FINISHED } state_e;
  endclass

  class enum_derived extends enum_base;
    typedef struct {
      state_e state;
      bit value;
    } state_info_t;

    state_info_t info;

    extern function bit is_finished();
  endclass

  function bit enum_derived::is_finished();
    return info.state == FINISHED;
  endfunction
endpackage

module main;
  import inherited_enum_pkg::*;
  initial begin
    enum_derived obj;
    obj = new;
    obj.info = '{enum_base::FINISHED, 1'b1};
    if (!obj.is_finished()) begin
      $display("FAILED");
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
