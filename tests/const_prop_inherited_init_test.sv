// A derived class with multiple `const` properties (initialized at
// declaration) must initialize all of them in its constructor.  netclass_t::
// get_prop_initialized() indexed property_table_ with the absolute property
// index (including inherited properties) instead of subtracting the
// super-class property count (as set_prop_initialized does), so for the 2nd+
// const property it read out of bounds -> garbage "already initialized" ->
// "Property X is constant in this method" + "missing initialization".  This
// is the OpenTitan aon_timer_env_cov pattern (max_wkup/max_wdog/max_prescaler
// const properties in a class extending cip_base_env_cov).
class base_with_props;
  int      a;
  string   s;
  bit [3:0] b;
  function new(); a = 1; endfunction
endclass

class derived extends base_with_props;
  const int        c_int  = 7;
  const bit [7:0]  c_byte = 8'hA5;
  const bit [11:0] c_wide = 12'hFFF;
  function new();
    super.new();
  endfunction
endclass

module const_prop_inherited_init_test;
  initial begin
    derived d = new();
    if (d.c_int == 7 && d.c_byte == 8'hA5 && d.c_wide == 12'hFFF && d.a == 1)
      $display("PASS c_int=%0d c_byte=%02h c_wide=%03h", d.c_int, d.c_byte, d.c_wide);
    else
      $display("FAIL c_int=%0d c_byte=%02h c_wide=%03h a=%0d",
               d.c_int, d.c_byte, d.c_wide, d.a);
    $finish;
  end
endmodule
