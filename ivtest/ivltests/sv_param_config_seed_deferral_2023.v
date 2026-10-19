// A generic container must not seed virtual method bodies before its type
// parameter is concrete.
class item_config;
  int id;
endclass

class base_driver #(type CONFIG_T);
  CONFIG_T cfg;
  bit ran;

  virtual task run();
    if (cfg.id != 42)
      $fatal(1, "forwarded config property did not resolve");
    ran = 1'b1;
  endtask
endclass

class env_container #(type C);
  base_driver#(C) drv;
endclass

module sv_param_config_seed_deferral;
  env_container#(item_config) env;

  initial begin
    env = new;
    env.drv = new;
    env.drv.cfg = new;
    env.drv.cfg.id = 42;
    env.drv.run();
    if (!env.drv.ran)
      $fatal(1, "deferred virtual method body was not elaborated");
    $display("PASSED");
  end
endmodule
