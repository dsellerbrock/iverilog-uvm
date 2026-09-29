// IEEE 1800-2017/2023 18.7: an inline constraint can sample a method
// through a nested handle owned by the randomize() caller. The target's
// property takes precedence when the same root also exists on the target.
class nested_reg;
  int unsigned width;
  virtual function int unsigned get_n_bits();
    return width;
  endfunction
endclass

class nested_reg_child extends nested_reg;
  virtual function int unsigned get_n_bits();
    return width + 1;
  endfunction
endclass

class nested_ral;
  nested_reg idcode;
  function new(); idcode = new; endfunction
endclass

class nested_jtag_cfg;
  nested_ral jtag_dtm_ral;
  function new(); jtag_dtm_ral = new; endfunction
endclass

class nested_env_cfg;
  nested_jtag_cfg m_jtag_agent_cfg;
  function new(); m_jtag_agent_cfg = new; endfunction
endclass

class nested_item;
  rand bit [5:0] dr_len;
  constraint c_len { dr_len < 31; }
endclass

class nested_target_item;
  rand bit [5:0] dr_len;
  nested_env_cfg cfg;
  function new(); cfg = new; endfunction
endclass

class nested_seq;
  nested_env_cfg cfg;
  nested_item req;
  nested_target_item target;
  function new();
    cfg = new;
    req = new;
    target = new;
  endfunction
  function bit draw();
    return req.randomize() with {
      dr_len == cfg.m_jtag_agent_cfg.jtag_dtm_ral.idcode.get_n_bits();
    };
  endfunction
  function bit draw_target();
    return target.randomize() with {
      dr_len == cfg.m_jtag_agent_cfg.jtag_dtm_ral.idcode.get_n_bits();
    };
  endfunction
endclass

module top;
  nested_seq seq;
  initial begin
    seq = new;
    seq.cfg.m_jtag_agent_cfg.jtag_dtm_ral.idcode.width = 16;
    if (!seq.draw() || seq.req.dr_len != 16)
      $fatal(1, "nested caller method returned wrong width");
    seq.cfg.m_jtag_agent_cfg.jtag_dtm_ral.idcode.width = 23;
    if (!seq.draw() || seq.req.dr_len != 23)
      $fatal(1, "nested caller method was not sampled per call");
    begin
      nested_reg_child child;
      child = new;
      child.width = 29;
      seq.cfg.m_jtag_agent_cfg.jtag_dtm_ral.idcode = child;
    end
    if (!seq.draw() || seq.req.dr_len != 30)
      $fatal(1, "nested caller virtual method used wrong override");
    seq.cfg.m_jtag_agent_cfg.jtag_dtm_ral.idcode.width = 30;
    if (seq.draw() || seq.req.dr_len != 30)
      $fatal(1, "unsatisfiable nested method did not roll back");
    seq.target.cfg.m_jtag_agent_cfg.jtag_dtm_ral.idcode.width = 7;
    if (!seq.draw_target() || seq.target.dr_len != 7)
      $fatal(1, "nested randomized target lost lookup precedence");
    $display("PASSED");
  end
endmodule
