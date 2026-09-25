// A declared nested child is type-correct without a concrete parent instance.
// Selecting it through a null parent VIF must fail at runtime.
interface nested_value_no_instance_leaf_if;
endinterface

interface nested_value_no_instance_outer_if;
  nested_value_no_instance_leaf_if child();
endinterface

class nested_value_no_instance_holder;
  virtual nested_value_no_instance_outer_if vif;
endclass

module sv_vif_class_nested_value_null_no_instance_fail;
  nested_value_no_instance_holder holder;

  task automatic take(virtual nested_value_no_instance_leaf_if value);
    $fatal(1, "UNREACHABLE null nested child reached task");
  endtask

  initial begin
    holder = new;
    take(holder.vif.child);
    $display("UNREACHABLE null nested child accepted");
  end
endmodule
