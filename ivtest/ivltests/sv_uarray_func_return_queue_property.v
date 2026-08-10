// A fixed unpacked-array function result is assignment-compatible with a
// queue of the same element type. Class properties need the same conversion
// as signal-backed queues, and the stored value must remain a real queue so
// queue-only mutations work after the assignment.

typedef int    int_fixed_t[2:0];
typedef real   real_fixed_t[-1:1];
typedef string string_fixed_t[4:6];

class queue_holder;
  int    ints[$];
  int    bounded[$:1];
  real   reals[$];
  string strings[$];
endclass

module main;
  queue_holder holder;
  int calls;
  bit failed;

  function automatic int_fixed_t make_ints();
    calls = calls + 1;
    make_ints[2] = 11;
    make_ints[1] = 22;
    make_ints[0] = 33;
  endfunction

  function automatic real_fixed_t make_reals();
    calls = calls + 1;
    make_reals = '{1.25, 2.5, 3.75};
  endfunction

  function automatic string_fixed_t make_strings();
    calls = calls + 1;
    make_strings = '{"red", "green", "blue"};
  endfunction

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    holder = new;

    calls = 0;
    holder.ints = make_ints();
    check("integral function evaluated once", calls == 1);
    check("integral queue contents",
          holder.ints.size() == 3 && holder.ints[0] == 11 &&
          holder.ints[1] == 22 && holder.ints[2] == 33);
    holder.ints.push_back(44);
    check("integral queue mutation",
          holder.ints.size() == 4 && holder.ints[3] == 44);

    holder.bounded = make_ints();
    check("bounded function evaluated once", calls == 2);
    check("bounded queue truncation",
          holder.bounded.size() == 2 && holder.bounded[0] == 11 &&
          holder.bounded[1] == 22);
    check("bounded queue pop", holder.bounded.pop_back() == 22);
    holder.bounded.push_back(55);
    check("bounded queue mutation",
          holder.bounded.size() == 2 && holder.bounded[1] == 55);

    holder.reals = make_reals();
    check("real function evaluated once", calls == 3);
    check("real queue contents",
          holder.reals.size() == 3 && holder.reals[0] == 1.25 &&
          holder.reals[1] == 2.5 && holder.reals[2] == 3.75);
    holder.reals.push_back(4.5);
    check("real queue mutation",
          holder.reals.size() == 4 && holder.reals[3] == 4.5);

    holder.strings = make_strings();
    check("string function evaluated once", calls == 4);
    check("string queue contents",
          holder.strings.size() == 3 && holder.strings[0] == "red" &&
          holder.strings[1] == "green" && holder.strings[2] == "blue");
    holder.strings.push_back("white");
    check("string queue mutation",
          holder.strings.size() == 4 && holder.strings[3] == "white");

    if (failed)
      $fatal(1, "fixed-array function return queue-property checks failed");
    $display("PASSED");
  end
endmodule
