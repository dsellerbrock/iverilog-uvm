module sv_param_class_scoped_static_lvalue_nested;
  class payload;
    int field;
  endclass

  class wrapper #(int VALUE = 1);
    static payload obj;
    static int values[3];
    static int scalar;
  endclass

  typedef wrapper default_wrapper;
  payload default_payload;
  payload alternate_payload;
  event update_event;

  task automatic set_output(output int value);
    value = 41;
  endtask

  task automatic bump_inout(inout int value);
    value += 2;
  endtask

  task automatic set_reference(ref int value);
    value = 51;
  endtask

  initial begin
    default_payload = new;
    alternate_payload = new;
    wrapper#()::obj = default_payload;
    wrapper#(2)::obj = alternate_payload;

    wrapper#()::obj.field = 5;
    wrapper#(2)::obj.field = 200;
    wrapper#()::values[0] = 7;
    wrapper#(2)::values[0] = 70;

    wrapper#()::obj.field += 3;
    ++wrapper#()::obj.field;
    wrapper#()::obj.field++;
    wrapper#()::values[0] += 3;
    ++wrapper#()::values[0];
    wrapper#()::values[0]++;

    wrapper#()::obj.field <= 15;
    wrapper#()::values[0] <= 16;
    #1;

    wrapper#()::values[1] = #0 20;
    fork
      begin
        #1 -> update_event;
      end
      begin
        wrapper#()::values[1] = @(update_event) 21;
      end
    join

    force wrapper#()::scalar = 30;
    if (wrapper#()::scalar !== 30)
      $fatal(1, "force did not update static storage");
    release wrapper#()::scalar;
    wrapper#()::scalar = 31;

    for (wrapper#()::values[0] = 0;
         wrapper#()::values[0] < 2;
         wrapper#()::values[0]++)
      ;

    set_output(wrapper#()::values[1]);
    bump_inout(wrapper#()::obj.field);
    set_reference(wrapper#()::values[2]);

    if (default_wrapper::obj.field !== 17
        || default_wrapper::values[0] !== 2
        || default_wrapper::values[1] !== 41
        || default_wrapper::values[2] !== 51
        || default_wrapper::scalar !== 31
        || wrapper#(2)::obj.field !== 200
        || wrapper#(2)::values[0] !== 70)
      $fatal(1, "nested/indexed storage or actual binding mismatch");
    $display("PASSED");
  end
endmodule
