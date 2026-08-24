// Resolving a nested static call through an inherited type parameter must
// preserve normal argument checking; it must not fall back to an ignored task.
module sv_inherited_typeparam_nested_static_call_fail;
  class registry;
    static function void set_inst_override(int wrapper, string inst_path);
    endfunction

    static function int get_inst_override();
      return 1;
    endfunction
  endclass

  class default_driver;
    typedef registry type_id;
  endclass

  class reactive_agent #(type DRIVER_T = default_driver);
  endclass

  class alert_agent extends reactive_agent#(default_driver);
    function void build_phase();
      int value;
      DRIVER_T::type_id::set_inst_override();
      value = DRIVER_T::type_id::get_inst_override(1);
    endfunction
  endclass

  initial begin
    alert_agent agent;
    agent = new;
    agent.build_phase();
  end
endmodule
