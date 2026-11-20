module issue3510_clockvar_fail;
  bit clk = 0;
  bit a, b, d, e, mapped;
  struct packed { bit flag; } c;
  bit colliding_array[2];
  always #5 clk = !clk;

  property uses_actual(untyped x);
    x.flag;
  endproperty

  clocking cb @(posedge clk);
    default input #2;
    input #2 a;
    input c;
    inout d;
    input negedge e;
    property direct_read;
      a;
    endproperty
    sequence nested(untyped x);
      b ##1 x;
    endsequence
    property via_sequence;
      nested(1'b1);
    endproperty
    property via_actual;
      uses_actual(c);
    endproperty
    property via_default(untyped x = d);
      x;
    endproperty
    property edge_read;
      e;
    endproperty
    property array_name;
      colliding_array === colliding_array;
    endproperty
    input b;
    input colliding_array = mapped;
  endclocking

  assert property (cb.direct_read);
  assert property (cb.via_sequence);
  assert property (cb.via_actual);
  assert property (cb.via_default());
  assert property (cb.edge_read);
  assert property (cb.array_name);
endmodule
