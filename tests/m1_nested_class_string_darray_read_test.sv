// IEEE 1800-2017 7.5 and 8.4: an indexed string dynamic-array property
// remains readable when its owning object is itself reached through a class
// property (the cfg.names[i] shape used throughout OpenTitan UVM).

class m1_string_darray_cfg;
  string names[];

  function new();
    names = new[2];
    names[0] = "recoverable";
    names[1] = "fatal";
  endfunction
endclass

class m1_string_darray_env;
  m1_string_darray_cfg cfg;

  function new();
    cfg = new;
  endfunction

  function string joined_names();
    string result = "";
    foreach (cfg.names[i]) begin
      string name = cfg.names[i];
      result = {result, name};
    end
    return result;
  endfunction
endclass

module m1_nested_class_string_darray_read_test;
  initial begin
    m1_string_darray_env env;
    env = new;
    if (env.joined_names() != "recoverablefatal") begin
      $display("FAIL: nested string darray read produced '%s'",
               env.joined_names());
      $finish(1);
    end
    $display("PASS");
  end
endmodule
