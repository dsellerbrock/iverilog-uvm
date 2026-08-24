// A derived class inherits the concrete bindings of its parameterized base.
// Those inherited type parameters may name a class, then a nested typedef,
// then a static void/value function. This is the factory-override spelling
// used by OpenTitan's alert_esc_agent.
module sv_inherited_typeparam_nested_static_call;
  class registry #(type ITEM_T = int);
    static int selected;

    static function void set_inst_override(int wrapper,
                                           string inst_path,
                                           int parent = 0);
      selected = wrapper + inst_path.len() + parent;
    endfunction

    static function int get_inst_override();
      return selected;
    endfunction
  endclass

  class default_driver;
    typedef registry#(default_driver) type_id;
  endclass

  class default_monitor;
    typedef registry#(default_monitor) type_id;
  endclass

  class fallback_driver;
    typedef registry#(fallback_driver) type_id;
  endclass

  class fallback_monitor;
    typedef registry#(fallback_monitor) type_id;
  endclass

  class reactive_agent #(type DRIVER_T = fallback_driver,
                          type MONITOR_T = fallback_monitor);
  endclass

  class alert_agent extends reactive_agent #(
      .DRIVER_T(default_driver),
      .MONITOR_T(default_monitor)
  );
    function void build_phase();
      DRIVER_T::type_id::set_inst_override(40, "driver", 1);
      MONITOR_T::type_id::set_inst_override(50, "monitor");
    endfunction

    function int driver_override();
      return DRIVER_T::type_id::get_inst_override();
    endfunction

    function int monitor_override();
      return MONITOR_T::type_id::get_inst_override();
    endfunction
  endclass

  initial begin
    alert_agent agent;
    agent = new;
    agent.build_phase();
    if (agent.driver_override() != 47 || agent.monitor_override() != 57
        || default_driver::type_id::get_inst_override() != 47
        || default_monitor::type_id::get_inst_override() != 57
        || fallback_driver::type_id::get_inst_override() != 0
        || fallback_monitor::type_id::get_inst_override() != 0)
      $fatal(1, "inherited type-parameter nested static dispatch failed");
    $display("PASSED");
  end
endmodule
