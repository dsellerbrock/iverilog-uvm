package enum_class_shadow_pkg;
  typedef enum int {
    PACKAGE_A = 1,
    PACKAGE_B = 2
  } state_e;

  class shadow_holder;
    typedef enum int {
      CLASS_A = 3,
      CLASS_B = 4
    } state_e;

    state_e state = CLASS_A;

    function state_e get();
      return state;
    endfunction

    function void advance();
      state = CLASS_B;
    endfunction

    extern function void set(state_e value);
  endclass

  function void shadow_holder::set(state_e value);
    state = value;
  endfunction
endpackage

module sv_enum_class_typedef_shadow;
  import enum_class_shadow_pkg::*;

  initial begin
    shadow_holder holder;
    holder = new;
    if (holder.get() != 3) begin
      $display("FAILED");
      $finish(1);
    end
    holder.advance();
    if (holder.get() != 4) begin
      $display("FAILED");
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
