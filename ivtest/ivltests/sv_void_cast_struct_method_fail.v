// A void cast discards a function result; it must not convert a task call into
// an expression merely because the task receiver is stored in a struct.
class void_struct_task_worker;
  task run();
  endtask
endclass

typedef struct {
  void_struct_task_worker object;
} void_struct_task_holder_t;

module sv_void_cast_struct_method_fail;
  void_struct_task_holder_t holder;

  initial begin
    holder.object = new;
    void'(holder.object.run());
  end
endmodule
