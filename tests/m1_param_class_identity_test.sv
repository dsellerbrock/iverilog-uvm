class item_t;
endclass

class cfg_t;
endclass

class other_item_t;
endclass

class base_t #(type ITEM_T = item_t,
               type CFG_T = cfg_t,
               type RSP_T = ITEM_T);
  typedef base_t #(.ITEM_T(ITEM_T),
                   .CFG_T(CFG_T),
                   .RSP_T(RSP_T)) this_type;
  this_type self;
endclass

class derived_t extends base_t #(item_t, cfg_t);
endclass

class generic_holder_t #(type VALUE_T = base_t);
  VALUE_T value;
endclass

class concrete_holder_t extends generic_holder_t #(base_t #(item_t, cfg_t));
endclass

module top;
  base_t #(item_t, cfg_t) base;
  base_t #(other_item_t, cfg_t) other_base;
  derived_t derived;
  concrete_holder_t holder;

  initial begin
    derived = new;
    holder = new;
    if (!$cast(base, derived)) begin
      $display("FAIL parameterized base class identity was not preserved");
      $finish;
    end
    if (!$cast(holder.value, derived)) begin
      $display("FAIL nested type-parameter specialization lost class identity");
      $finish;
    end
    base = new;
    if (!$cast(base.self, derived)) begin
      $display("FAIL named and positional specializations lost class identity");
      $finish;
    end
    other_base = new;
    if ($cast(other_base, derived)) begin
      $display("FAIL distinct parameterized class types were merged");
      $finish;
    end
    $display("PASS");
    $finish;
  end
endmodule
