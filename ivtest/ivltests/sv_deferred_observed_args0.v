module t;
  class payload;
    int id;
  endclass

  class worker;
    int value = 7;
    int calls = 0;

    function int sample();
      calls += 1;
      return value;
    endfunction

    task automatic run();
      int local_value = 11;
      real real_value;
      string string_value;
      int dynamic_value[];
      int queue_value[$];
      payload object_value;

      real_value = 3.25;
      string_value = "original";
      dynamic_value = '{8, 9};
      queue_value = '{6, 7};
      object_value = new;
      object_value.id = 37;

      assert #0 (0) else
        $display("%s", $sformatf("OBS LOCAL=%0d VALUE=%0d SAMPLE=%0d",
                                  local_value, value, sample()));
      assert #0 (0) else
        $display("MIX LOCAL=%0d REAL=%0.2f STRING=%s DYNAMIC=%p QUEUE=%p OBJECT=%p",
                 local_value, real_value, string_value, dynamic_value,
                 queue_value, object_value);
      local_value = 99;
      real_value = 4.5;
      string_value = "changed";
      dynamic_value = '{98};
      queue_value = '{99};
      object_value = null;
      value = 88;
      $display("SOURCE VALUE=%0d CALLS=%0d", value, calls);
    endtask
  endclass

  function automatic int function_source(input int input_value);
    int local_value;
    local_value = input_value;
    assert #0 (0)
      else $display("FUNCTION %m VALUE=%0d", local_value);
    local_value = 99;
    return local_value;
  endfunction

  worker w;
  int sink;
  initial begin
    w = new;
    sink = function_source(23);
    w.run();
    #1 $display("AFTER VALUE=%0d CALLS=%0d SINK=%0d",
                w.value, w.calls, sink);
  end
endmodule
