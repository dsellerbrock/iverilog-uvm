// A class that is NOT parameterized but carries `localparam` members must be
// usable as a scope qualifier (Class::static_prop, Class::some_type,
// Class::LOCALPARAM) without #(...).  iverilog recorded localparams in the
// class's parameter_order and wrongly treated such a class as parameterized,
// rejecting "Class::X" with "Parameterized class 'Class' used as scope
// qualifier without explicit parameter specification (#(...))".  This is the
// OpenTitan usbdev_bfm pattern (usbdev_bfm::InvalidEP / ::type_id /
// ::rxfifo_entry_t -- the class extends uvm_component, no #() port).
class bfm_like;            // no parameter port list -- only localparams
  localparam int unsigned BUF_W = 6;
  localparam bit [3:0]    INVALID = 4'hF;
  typedef enum { EP0, EP1, EP2 } ep_e;
  static int next_id = 0;
endclass

module class_localparam_scope_qualifier_test;
  initial begin
    int        w  = bfm_like::BUF_W;        // localparam via scope
    bit [3:0]  iv = bfm_like::INVALID;       // localparam via scope
    bfm_like::ep_e e = bfm_like::EP2;        // class-scoped type + value
    int        id = bfm_like::next_id;       // static property via scope

    if (w == 6 && iv == 4'hF && e == bfm_like::EP2 && id == 0)
      $display("PASS w=%0d iv=%0h e=%0d id=%0d", w, iv, e, id);
    else
      $display("FAIL w=%0d iv=%0h e=%0d id=%0d", w, iv, e, id);
    $finish;
  end
endmodule
