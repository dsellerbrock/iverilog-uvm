// A type parameter forwarded through a derived class keeps the inherited
// property type for nested member selection in the derived method body.
class kv_hmac_sequencer;
  bit observed;
endclass

class kv_hmac_write_agent_config;
  kv_hmac_sequencer sequencer;

  function new();
    sequencer = new;
  endfunction
endclass

class kv_env_configuration;
  kv_hmac_write_agent_config kv_hmac_write_agent_config;

  function new();
    kv_hmac_write_agent_config = new;
  endfunction
endclass

class uvmf_virtual_sequence_base #(type CONFIG_T);
  CONFIG_T configuration;

  function new(CONFIG_T value);
    configuration = value;
  endfunction

  function bit has_valid_sequencer();
    has_valid_sequencer =
      configuration.kv_hmac_write_agent_config.sequencer != null;
  endfunction
endclass

class kv_env_sequence_base #(type CONFIG_T)
  extends uvmf_virtual_sequence_base#(.CONFIG_T(CONFIG_T));
  function new(CONFIG_T value);
    super.new(value);
  endfunction

  virtual task body();
    if (configuration.kv_hmac_write_agent_config.sequencer == null)
      $fatal(1, "configuration sequencer was not constructed");
    configuration.kv_hmac_write_agent_config.sequencer.observed = 1'b1;
  endtask
endclass

module sv_param_config_nested_path;
  kv_env_configuration configuration;
  kv_env_sequence_base#(kv_env_configuration) seq_obj;

  initial begin
    configuration = new;
    seq_obj = new(configuration);
    seq_obj.body();
    if (!seq_obj.has_valid_sequencer())
      $fatal(1, "nested read through forwarded base type was lost");
    if (!configuration.kv_hmac_write_agent_config.sequencer.observed)
      $fatal(1, "nested write through inherited configuration was lost");
    $display("PASSED");
  end
endmodule
