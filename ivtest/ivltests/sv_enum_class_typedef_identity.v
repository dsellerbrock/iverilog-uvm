package enum_class_identity_pkg;
  typedef enum int {
    IDLE = 0,
    BUSY = 1
  } status_e;
  typedef status_e status_alias_e;

  class status_holder;
    status_e status = IDLE;
    status_alias_e alias_status = IDLE;

    function new(status_e initial_status = IDLE);
      status = initial_status;
      alias_status = initial_status;
    endfunction

    function status_e inline_get();
      return status;
    endfunction

    function void inline_set(status_e value);
      status = value;
    endfunction

    extern function status_e extern_get();
    extern function void extern_set(status_e value);
  endclass

  function status_e status_holder::extern_get();
    return status;
  endfunction

  function void status_holder::extern_set(status_e value);
    status = value;
  endfunction
endpackage

package enum_class_import_pkg;
  import enum_class_identity_pkg::*;

  class imported_holder;
    status_e status = BUSY;

    function status_e get();
      return status;
    endfunction

    function void set(status_e value);
      status = value;
    endfunction
  endclass
endpackage

module sv_enum_class_typedef_identity;
  import enum_class_identity_pkg::*;
  import enum_class_import_pkg::*;

  initial begin
    status_holder direct;
    imported_holder imported;

    direct = new(BUSY);
    if (direct.inline_get() != BUSY || direct.alias_status != BUSY) begin
      $display("FAILED");
      $finish(1);
    end

    direct.inline_set(IDLE);
    direct.extern_set(BUSY);
    if (direct.extern_get() != BUSY) begin
      $display("FAILED");
      $finish(1);
    end

    imported = new;
    imported.set(IDLE);
    if (imported.get() != IDLE) begin
      $display("FAILED");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
