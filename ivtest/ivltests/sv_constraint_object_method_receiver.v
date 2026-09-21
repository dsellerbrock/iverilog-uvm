class receiver_field_base;
  bit [63:0] desired;
  bit [63:0] resets[string];
  int bias;
  virtual function bit [63:0] get_reset(string kind = "HARD");
    if (!resets.exists(kind)) return desired;
    return resets[kind];
  endfunction
  function int add_bias(input int value); return value + bias; endfunction
  static function int static_value(); return 17; endfunction
endclass

class receiver_field_derived extends receiver_field_base;
  virtual function bit [63:0] get_reset(string kind = "HARD");
    if (!resets.exists(kind)) return desired + 1;
    return resets[kind] + 1;
  endfunction
endclass

class receiver_control_reg;
  receiver_field_base core_clk_en;
  function new;
    receiver_field_derived field = new;
    core_clk_en = field;
  endfunction
endclass

class receiver_ral_block;
  receiver_control_reg control;
  function new; control = new; endfunction
endclass

class receiver_signed_base;
  virtual function bit signed [63:0] read(); return -64'sd1; endfunction
endclass
class receiver_signed_derived extends receiver_signed_base;
  virtual function bit signed [63:0] read(); return -64'sd19; endfunction
endclass

class receiver_item;
  rand bit [63:0] reset_value;
  rand int argument;
  rand int argument_value;
  rand int static_result;
  rand bit signed [63:0] signed_result;
  receiver_ral_block ral;
  receiver_field_base null_static_receiver;
  receiver_signed_base signed_receiver;
  constraint c {
    reset_value == ral.control.core_clk_en.get_reset();
    argument == 7;
    argument_value == ral.control.core_clk_en.add_bias(argument);
    static_result == null_static_receiver.static_value();
    signed_result == signed_receiver.read();
  }
  function new;
    receiver_signed_derived actual = new;
    ral = new;
    signed_receiver = actual;
  endfunction
  function void pre_randomize();
    ral.control.core_clk_en.desired = 64'h30;
    ral.control.core_clk_en.bias = 5;
  endfunction
endclass

module test;
  receiver_item value;
  string rng;
  bit [63:0] old_reset;
  int old_argument, old_argument_value;
  initial begin
    value = new;
    value.srandom(32'h4d455448);
    if (!value.randomize() || value.reset_value != 64'h31
        || value.argument != 7 || value.argument_value != 12
        || value.static_result != 17 || value.signed_result != -64'sd19)
      $fatal(1, "object method values r=%h a=%0d av=%0d st=%0d sg=%0d",
             value.reset_value, value.argument, value.argument_value,
             value.static_result, value.signed_result);

    value.ral.control.core_clk_en.resets["HARD"] = 64'h50;
    if (!value.randomize() || value.reset_value != 64'h51)
      $fatal(1, "object method state refresh r=%h", value.reset_value);

    old_reset = value.reset_value;
    old_argument = value.argument;
    old_argument_value = value.argument_value;
    rng = value.get_randstate();
    if (value.randomize() with { reset_value == 64'h99; })
      $fatal(1, "object method contradiction succeeded");
    if (value.reset_value != old_reset || value.argument != old_argument
        || value.argument_value != old_argument_value
        || value.get_randstate() != rng)
      $fatal(1, "object method contradiction rollback");
    $display("PASSED");
  end
endmodule
