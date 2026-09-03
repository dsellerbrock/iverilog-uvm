// IEEE 1800-2017/2023 13.4, 13.5, 25.8, and 25.9: task and
// value-returning function dispatch must use the bound interface instance's
// complete parameter specialization, including argument and result widths.
interface param_vif_method_if #(parameter WIDTH = 8);
  logic [WIDTH-1:0] data;

  task automatic drive(input logic [WIDTH-1:0] value);
    data = value;
  endtask

  function automatic logic [WIDTH-1:0] sample(
      input logic [WIDTH-1:0] bias = '0);
    sample = data + bias;
  endfunction
endinterface

typedef virtual interface param_vif_method_if #(17) method_vif17_t;

class specialization_method_holder;
  method_vif17_t vif;
endclass

module sv_vif_parameter_specialization_methods;
  param_vif_method_if default8();
  param_vif_method_if #(17) ordered17();
  param_vif_method_if #(.WIDTH(17)) named17();
  virtual interface param_vif_method_if #() default_vif;
  specialization_method_holder holder;

  initial begin
    holder = new;

    default_vif = default8;
    default_vif.drive(8'h5a);
    if (default_vif.sample() !== 8'h5a)
      $fatal(1, "default task/function dispatch failed");

    holder.vif = ordered17;
    holder.vif.drive(.value(17'h1cafe));
    if (holder.vif.sample() !== 17'h1cafe)
      $fatal(1, "ordered W17 task/function dispatch failed");

    // Rebind the same class property to an equivalently named specialization.
    holder.vif = named17;
    holder.vif.drive(17'h12345);
    if (holder.vif.sample(.bias(17'h00011)) !== 17'h12356)
      $fatal(1, "named W17 task/function dispatch failed");

    $display("PASSED");
  end
endmodule
