class base_library;
  static int total;
  static function void add_typewide_sequence(int value);
    total += value;
  endfunction
  static function int add_and_return(int value);
    total += value;
    return total;
  endfunction
endclass

class inherited_library extends base_library;
endclass

class second_library;
  static int total;
  static function void add_typewide_sequence(int value);
    total += 10*value;
  endfunction
  static function int add_and_return(int value);
    total += 10*value;
    return total;
  endfunction
endclass

class receiver_base;
  int value;
  function void put(int next);
    value = next;
  endfunction
endclass

class receiver_derived extends receiver_base;
  function void call_base(int next);
    receiver_base::put(next);
  endfunction
endclass

class library_adder #(type LIBTYPE = int);
  function void add(int value);
    LIBTYPE::add_typewide_sequence(value);
  endfunction
  function void add_ignoring_return(int value);
    LIBTYPE::add_and_return(value);
  endfunction
endclass

module test;
  library_adder#(inherited_library) inherited_adder;
  library_adder#(second_library) second_adder;
  receiver_derived receiver;
  initial begin
    base_library::total = 0;
    second_library::total = 0;
    inherited_adder = new;
    second_adder = new;
    receiver = new;
    inherited_adder.add(3);
    inherited_adder.add_ignoring_return(4);
    second_adder.add(5);
    receiver.call_base(19);
    if (base_library::total !== 7 || second_library::total !== 50)
      $fatal(1, "FAILED base=%0d second=%0d",
             base_library::total, second_library::total);
    if (receiver.value !== 19)
      $fatal(1, "FAILED inherited receiver value=%0d", receiver.value);
    $display("PASSED");
  end
endmodule
