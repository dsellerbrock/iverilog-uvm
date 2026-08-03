// IEEE 1800-2017 9.4.3/25.9: a wait expression reached through any number
// of class properties to a virtual-interface member must wake when that
// interface signal changes.
interface m8_deep_wait_if;
  int pulses = 0;
endinterface

class m8_deep_wait_agent_cfg;
  virtual m8_deep_wait_if vif;
endclass

class m8_deep_wait_env_cfg;
  m8_deep_wait_agent_cfg agent_cfg;
endclass

class m8_deep_wait_seq;
  m8_deep_wait_env_cfg cfg;
  bit released;

  task wait_until_safe(bit enable = 1'b1);
    wait (!(enable && cfg.agent_cfg.vif.pulses inside {1, 2}));
    released = 1'b1;
  endtask
endclass

module m8_vif_deep_property_wait_test;
  m8_deep_wait_if intf();
  m8_deep_wait_seq seq;

  initial begin
    seq = new;
    seq.cfg = new;
    seq.cfg.agent_cfg = new;
    seq.cfg.agent_cfg.vif = intf;
    intf.pulses = 2;

    fork
      seq.wait_until_safe();
    join_none

    #1;
    if (seq.released !== 1'b0) begin
      $display("FAILED: deep virtual-interface wait did not block");
      $finish_and_return(1);
    end

    intf.pulses = 0;
    #1;
    if (seq.released !== 1'b1) begin
      $display("FAILED: deep virtual-interface wait did not wake");
      $finish_and_return(1);
    end

    $display("PASSED: deep virtual-interface property wait woke");
    $finish;
  end
endmodule
