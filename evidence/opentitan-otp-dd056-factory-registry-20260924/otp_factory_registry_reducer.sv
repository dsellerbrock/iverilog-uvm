module otp_factory_registry_reducer;
  class base;
  endclass

  class registry #(type T = base, string Name = "<unknown>");
    typedef registry#(T, Name) this_type;
    static this_type me;

    static function this_type get();
      if (me == null) me = new;
      return me;
    endfunction

    function base create();
      T obj = new;
      return obj;
    endfunction
  endclass

  class sequencer #(int HostWidth = 32, int DeviceWidth = HostWidth) extends base;
    typedef registry#(sequencer#(HostWidth, DeviceWidth)) type_id;
    static function type_id get_type();
      return type_id::get();
    endfunction
  endclass

  class base_agent #(type S = sequencer#(32, 32));
    S item;
    function base make();
      item = S::get_type().create();
      return item;
    endfunction
  endclass

  class reactive_agent #(type S = sequencer#(32, 32))
      extends base_agent#(S);
  endclass

  class agent #(int HostWidth = 32, int DeviceWidth = HostWidth)
      extends reactive_agent#(sequencer#(HostWidth, DeviceWidth));
  endclass

  class base_consumer #(type S = sequencer#(32, 32));
    function bit accepts(base handle);
      S typed;
      return $cast(typed, handle);
    endfunction
  endclass

`ifdef POSITIONAL_CONTROL
  class consumer #(int HostWidth = 32, int DeviceWidth = HostWidth)
      extends base_consumer#(sequencer#(HostWidth, DeviceWidth));
`else
  class consumer #(int HostWidth = 32, int DeviceWidth = HostWidth)
      extends base_consumer#(sequencer#(.DeviceWidth(DeviceWidth)));
`endif
  endclass

  initial begin
    agent#(.DeviceWidth(33)) a;
    consumer#(.DeviceWidth(33)) same;
    consumer#(.DeviceWidth(34)) different;
    base handle;
    int failures = 0;
    a = new;
    same = new;
    different = new;
    handle = a.make();
    if (!same.accepts(handle)) begin
      $display("FAIL: same-parameter factory object rejected");
      failures++;
    end else begin
      $display("PASS: same-parameter factory object accepted");
    end
    if (different.accepts(handle)) begin
      $display("FAIL: unequal-parameter factory object accepted");
      failures++;
    end else begin
      $display("PASS: unequal-parameter factory object rejected");
    end
    if (failures) $fatal(1, "factory registry specialization failure");
  end
endmodule
