class collision #(parameter int Width = 4);
  static function int legal; return Width; endfunction
endclass
class collision_helper;
  int sampled;
  function int value(input int add); return sampled + add; endfunction
  function void sample(input int value); sampled = value; endfunction
endclass
class collision_base;
  protected collision_helper collision;
  collision_helper slots[2];
  int calls;
  function int index; calls++; return 1; endfunction
endclass
class collision_owner extends collision_base;
  function int argument_value(collision_helper collision);
    return collision.value(4);
  endfunction
  function void run;
    collision_helper collision;
    collision = new;
    collision.sample(4);
    if (collision.value(1) != 5) $fatal(1, "local shadow failed");
    this.collision = new;
    this.collision.sample(6);
    slots[1] = new;
    slots[index()].sample(8);
  endfunction
  function int result;
    return collision.value(3) + slots[1].value(2);
  endfunction
endclass
class collision_static_local;
  static function int run;
    collision_helper collision;
    collision = new;
    collision.sample(13);
    return collision.value(1);
  endfunction
endclass
module sv_implicit_property_method_collision_boundaries;
  initial begin
    collision_owner owner; collision_helper argument;
    owner = new; argument = new;
    argument.sample(5); owner.run();
    if (owner.calls != 1 || owner.result() != 19
        || owner.argument_value(argument) != 9
        || collision_static_local::run() != 14
        || collision#()::legal() != 4)
      $fatal(1, "implicit property method boundary failed");
    $display("PASSED");
  end
  initial begin : module_local_control
    collision_helper collision;
    collision = new;
    collision.sample(11);
    if (collision.value(1) != 12)
      $fatal(1, "module block local collision failed");
  end
endmodule
