// Declaration initializers execute before the subroutine body. If the body is
// a sole fork statement, the initializer must not become another fork branch.
// Cover inherited automatic locals and explicit automatic locals in a static
// task for each fork completion form.
module sv_subroutine_init_before_fork;
  int errors;
  int auto_join_value;
  int auto_join_any_value;
  int auto_join_none_value;
  int static_join_value;
  int static_join_any_value;
  int static_join_none_value;
  int detached_out[1:2];
  bit auto_join_any_seen;
  bit static_join_any_seen;

  task automatic auto_join;
    int value = 11;
    fork
      auto_join_value = value;
    join
  endtask

  task automatic auto_join_any;
    int value = 12;
    fork
      begin
        #1;
        auto_join_any_value = value;
        auto_join_any_seen = 1;
      end
    join_any
  endtask

  task automatic auto_join_none;
    int value = 13;
    fork
      auto_join_none_value = value;
    join_none
  endtask

  task static static_join;
    automatic int value = 21;
    fork
      static_join_value = value;
    join
  endtask

  task static static_join_any;
    automatic int value = 22;
    fork
      begin
        #1;
        static_join_any_value = value;
        static_join_any_seen = 1;
      end
    join_any
  endtask

  task static static_join_none;
    automatic int value = 23;
    fork
      static_join_none_value = value;
    join_none
  endtask

  // A detached branch keeps the activation that owns an explicit-automatic
  // local alive after this otherwise-static task returns. Two calls must not
  // share or recycle that activation while either branch remains live.
  task static static_detached(input int id);
    automatic int value;
    value = id;
    fork
      begin
        #(4-value);
        detached_out[value] = value * 10;
      end
    join_none
  endtask

  initial begin
    auto_join();
    if (auto_join_value !== 11)
      errors++;

    auto_join_any();
    if (auto_join_any_seen !== 1)
      errors++;
    #2;
    if (auto_join_any_value !== 12)
      errors++;

    auto_join_none();
    #1;
    if (auto_join_none_value !== 13)
      errors++;

    static_join();
    if (static_join_value !== 21)
      errors++;

    static_join_any();
    if (static_join_any_seen !== 1)
      errors++;
    #2;
    if (static_join_any_value !== 22)
      errors++;

    static_join_none();
    #1;
    if (static_join_none_value !== 23)
      errors++;

    static_detached(1);
    static_detached(2);
    #5;
    if (detached_out[1] !== 10 || detached_out[2] !== 20)
      errors++;

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED errors=%0d values=%0d,%0d,%0d,%0d,%0d,%0d detached=%0d,%0d",
               errors, auto_join_value, auto_join_any_value,
               auto_join_none_value, static_join_value,
               static_join_any_value, static_join_none_value,
               detached_out[1], detached_out[2]);
  end
endmodule
