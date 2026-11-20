// IEEE 1800-2017/2023 A.2.7 and 25.7: prototype ports may be unnamed.
interface issue3385_bus;
  int n = 0;
  extern task add(input int);
  extern function int combine(int, byte);
  modport provider(ref n, export add, combine);
  modport client(import task add(input int), task compare(input [3:0], var, output));

  task automatic compare(input logic [3:0] first, second, output logic different);
    different = first != second;
  endtask
endinterface

module issue3385_provider(issue3385_bus.provider a);
  task a.add(input int amount);
    a.n += amount;
  endtask

  function int a.combine(input int tens, byte ones);
    return 10 * tens + ones;
  endfunction
endmodule

virtual class issue3385_base;
  pure virtual function int adjust(input int);
  pure virtual function int zero_args();
  pure virtual function int pack_values(, byte, , input,);
  pure virtual task publish(input event, var);
endclass

class issue3385_derived extends issue3385_base;
  function int adjust(input int value);
    return value + 1;
  endfunction

  function int zero_args();
    return 19;
  endfunction

  function int pack_values(input logic head, input byte high, low,
                           input logic tail1, tail2);
    return 1000 * int'(head) + 100 * int'(high) + 10 * int'(low)
           + 2 * int'(tail1) + int'(tail2);
  endfunction

  task publish(input event first, second);
    ->first;
    ->second;
  endtask

  extern function int twice(int);
  extern task copy(input int, output);
endclass

function int issue3385_derived::twice(input int value);
  return 2 * value;
endfunction

task issue3385_derived::copy(input int value, output logic result);
  result = value == 7;
endtask

module issue3385;
  issue3385_bus i();
  issue3385_provider m(i.provider);
  virtual issue3385_bus.client client;
  issue3385_base base;
  issue3385_derived obj;
  logic result;
  event first, second;
  bit saw_first, saw_second;

  always @(first) saw_first = 1;
  always @(second) saw_second = 1;

  initial begin
    client = i.client;
    i.add(2);
    if (i.n !== 2)
      $fatal(1, "Wrong extern task result: %0d", i.n);
    $display("N %0d", i.n);

    if (i.combine(130, -3) !== 1297)
      $fatal(1, "Extern function formals lost their order, type, or value");
    client.compare(4'h9, 4'h1, result);
    if (result !== 1'b1)
      $fatal(1, "Wrong result from inherited packed formal type");

    obj = new;
    base = obj;
    if (base.adjust(10) !== 11 || base.zero_args() !== 19 || obj.twice(6) !== 12)
      $fatal(1, "Wrong class method result");
    if (base.pack_values(1'b1, 12, 7, 1'b1, 1'b0) !== 2272)
      $fatal(1, "Empty prototype slots lost their position or type");
    result = 0;
    obj.copy(7, result);
    if (result !== 1'b1)
      $fatal(1, "Unnamed extern task output was not copied out");
    #1;
    base.publish(first, second);
    #1;
    if (!saw_first || !saw_second)
      $fatal(1, "Unnamed event arguments lost their identity");
    $display("PASSED");
  end
endmodule
