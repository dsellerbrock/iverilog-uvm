// IEEE 1800-2017/2023 6.5, 10.3.2, 13.5.2: a ref actual aliases the
// interface member, so an active call is a live procedural writer.
interface mixed_ref_driver_if;
  logic value;
  task automatic dormant();
    value = 1'b1;
  endtask
endinterface

module sv_interface_task_mixed_driver_ref;
  mixed_ref_driver_if bus();
  virtual mixed_ref_driver_if handle;

  task automatic write_ref(ref logic target);
    target = 1'b1;
  endtask

  assign bus.value = 1'b0;
  initial begin
    handle = bus;
    write_ref(handle.value);
  end
endmodule

// A class-held virtual interface is an equally uncertain ref receiver.
class mixed_ref_driver_holder;
  virtual mixed_ref_driver_if handle;
endclass

module sv_interface_task_mixed_driver_ref_class;
  mixed_ref_driver_if bus();
  mixed_ref_driver_holder holder;

  task automatic write_ref(ref logic target);
    target = 1'b1;
  endtask

  assign bus.value = 1'b0;
  initial begin
    holder = new();
    holder.handle = bus;
    write_ref(holder.handle.value);
  end
endmodule
