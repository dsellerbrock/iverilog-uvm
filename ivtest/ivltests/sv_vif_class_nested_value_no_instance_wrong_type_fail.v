// The declared child type remains A even with no concrete outer instance.
// A task formal of unrelated interface B must reject the value at compile time.
interface nested_value_no_instance_a_if;
endinterface

interface nested_value_no_instance_b_if;
endinterface

interface nested_value_no_instance_wrong_type_outer_if;
  nested_value_no_instance_a_if child();
endinterface

class nested_value_no_instance_wrong_type_holder;
  virtual nested_value_no_instance_wrong_type_outer_if vif;
endclass

module sv_vif_class_nested_value_no_instance_wrong_type_fail;
  nested_value_no_instance_wrong_type_holder holder;

  task automatic take(virtual nested_value_no_instance_b_if value);
    $fatal(1, "UNREACHABLE mismatched child accepted");
  endtask

  initial begin
    holder = new;
    take(holder.vif.child);
  end
endmodule
