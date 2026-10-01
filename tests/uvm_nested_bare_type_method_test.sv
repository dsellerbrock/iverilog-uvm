interface otp_if;
  bit pin;
  function void drive(bit value);
    pin = value;
  endfunction
endinterface

package p;
  import uvm_pkg::*;
  int called;

  class cfg_t extends uvm_object;
    virtual otp_if vif;
    `uvm_object_utils(cfg_t)
    function new(string name = "cfg"); super.new(name); endfunction
  endclass

  class base_env #(type CFG = cfg_t) extends uvm_env;
    CFG cfg;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(CFG)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "base cfg missing")
      called = 1;
    endfunction
  endclass

  class env #(type CFG = cfg_t) extends base_env#(CFG);
    `uvm_component_param_utils(env#(CFG))
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual otp_if)::get(this, "", "vif", cfg.vif))
        `uvm_fatal("VIF", "OTP vif missing")
      called = 2;
      cfg.vif.drive(1);
      $display("ENV_OVERRIDE");
    endfunction
  endclass

`ifdef EXPLICIT_ENV_TYPEDEF
  typedef env#(cfg_t) env_c;
`endif
  class test #(type CFG = cfg_t, type ENV = env) extends uvm_test;
    typedef uvm_component_registry#(test#(CFG, ENV), "test") type_id;
    static function type_id get_type(); return type_id::get(); endfunction
    virtual function uvm_object_wrapper get_object_type(); return type_id::get(); endfunction
    virtual function string get_type_name(); return "test"; endfunction
    CFG cfg;
    ENV env_h;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg = new;
      env_h = ENV::type_id::create("env", this);
      uvm_config_db#(CFG)::set(this, "env", "cfg", cfg);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      if (called != 2 || cfg.vif == null || cfg.vif.pin !== 1)
        $fatal(1, "missing env override called=%0d", called);
      $display("PASS nested bare type method");
      phase.drop_objection(this);
    endtask
  endclass
endpackage

module top;
  import uvm_pkg::*;
  import p::*;
  otp_if physical();
`ifdef EXPLICIT_ENV_TYPEDEF
  typedef test#(cfg_t, env_c) concrete_test_t;
`else
  typedef test#(cfg_t, env) concrete_test_t;
`endif
  initial begin
    uvm_config_db#(virtual otp_if)::set(null, "*.env", "vif", physical);
    void'(concrete_test_t::get_type());
    run_test("test");
  end
endmodule
