// A class-held outer virtual interface must pass its actual nested interface
// instance by value to function and task formals (IEEE 1800-2017/2023).
interface nested_value_leaf_if #(parameter int WIDTH = 8);
  logic [WIDTH-1:0] payload;
  int marker = 0;
  modport read_only(input marker);
endinterface

interface nested_value_outer_if #(parameter int WIDTH = 8);
  nested_value_leaf_if #(.WIDTH(WIDTH)) child();
endinterface

class nested_value_cfg;
  virtual nested_value_outer_if #(17) vif;
endclass

class nested_value_sink;
  virtual nested_value_leaf_if #(17) from_function;
  virtual nested_value_leaf_if #(17) from_task;
  virtual nested_value_leaf_if #(17).read_only from_selected;

  function void put(virtual nested_value_leaf_if #(17) value);
    from_function = value;
  endfunction

  task automatic capture(virtual nested_value_leaf_if #(17) value);
    from_task = value;
  endtask

  function void put_selected(virtual nested_value_leaf_if #(17).read_only value);
    from_selected = value;
  endfunction
endclass

module sv_vif_class_nested_value_handoff;
  nested_value_outer_if #(17) outer0(), outer1();
  nested_value_outer_if other_layout();
  nested_value_cfg cfg;
  nested_value_cfg choices[2];
  nested_value_sink sink;
  int choose_calls = 0;

  function automatic int choose();
    choose_calls += 1;
    return 1;
  endfunction

  initial begin
    cfg = new;
    sink = new;
    cfg.vif = outer0;
    if (cfg.vif != outer0) $fatal(1, "parent VIF control failed");

    sink.put(outer0.child);
    if (sink.from_function != outer0.child)
      $fatal(1, "direct child control failed");

    sink.put(cfg.vif.child);
    if (sink.from_function != outer0.child)
      $fatal(1, "function lost outer0 child identity");
    sink.from_function.marker = 11;
    if (outer0.child.marker != 11 || outer1.child.marker != 0
        || other_layout.child.marker != 0)
      $fatal(1, "function value did not alias outer0 child");

    cfg.vif = outer1;
    sink.capture(cfg.vif.child);
    if (sink.from_task != outer1.child || sink.from_function != outer0.child)
      $fatal(1, "task selected wrong child after rebind");
    sink.from_task.marker = 22;
    if (outer0.child.marker != 11 || outer1.child.marker != 22
        || other_layout.child.marker != 0)
      $fatal(1, "task value did not alias outer1 child");

    sink.put_selected(cfg.vif.child);
    if (sink.from_selected.marker != 22)
      $fatal(1, "unqualified child did not reach selected modport formal");

    choices[0] = new;
    choices[0].vif = outer0;
    choices[1] = new;
    choices[1].vif = outer1;
    sink.put(choices[choose()].vif.child);
    if (choose_calls != 1 || sink.from_function != outer1.child)
      $fatal(1, "nested receiver evaluated more than once or misselected");
    cfg.vif = outer0;
    if (sink.from_function != outer1.child || sink.from_task != outer1.child)
      $fatal(1, "stored child handle followed parent rebind");
    $display("PASS nested value handoff");
  end
endmodule
