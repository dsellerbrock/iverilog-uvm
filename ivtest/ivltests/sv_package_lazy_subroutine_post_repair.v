package package_lazy_subroutine_post_repair_pkg;
  typedef class late_value;

  late_value global_value;
  late_value task_value;
  int init_calls;
  int task_calls;

  class caller_base #(type value_t = int);
    extern function void run_init();
    extern task run_task();
  endclass

  class caller extends caller_base#(int);
  endclass

  function void caller_base::run_init();
    init_once();
  endfunction

  task caller_base::run_task();
    init_task_once();
  endtask

  function void init_once();
    if (global_value == null) begin
      init_calls++;
      global_value = new(42);
    end
  endfunction

  task init_task_once();
    if (task_value == null) begin
      task_calls++;
      task_value = new(84);
    end
  endtask

  class late_value;
    int value;

    function new(input int value);
      this.value = value;
    endfunction
  endclass
endpackage

module sv_package_lazy_subroutine_post_repair;
  package_lazy_subroutine_post_repair_pkg::caller call;

  initial begin
    call = new;
    call.run_init();
    call.run_init();
    call.run_task();
    call.run_task();

    if (package_lazy_subroutine_post_repair_pkg::init_calls != 1)
      $fatal(1, "lazy package function guard used a stale signal type");
    if (package_lazy_subroutine_post_repair_pkg::global_value == null)
      $fatal(1, "lazy package function body stored a null class handle");
    if (package_lazy_subroutine_post_repair_pkg::global_value.value != 42)
      $fatal(1, "lazy package function constructed the wrong value");
    if (package_lazy_subroutine_post_repair_pkg::task_calls != 1)
      $fatal(1, "lazy package task guard used a stale signal type");
    if (package_lazy_subroutine_post_repair_pkg::task_value == null)
      $fatal(1, "lazy package task stored a null class handle");
    if (package_lazy_subroutine_post_repair_pkg::task_value.value != 84)
      $fatal(1, "lazy package task constructed the wrong value");

    $display("PASSED");
  end
endmodule
