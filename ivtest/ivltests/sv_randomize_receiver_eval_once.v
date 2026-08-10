// A method receiver is evaluated once before the method body. In
// particular, pre_randomize(), constraint solving, and post_randomize()
// all operate on that one receiver; they must not re-evaluate a function
// call used to obtain the handle.
class randomizable_item;
  rand int value;
  int pre_calls;
  int post_calls;

  constraint value_range { value inside {[1:10]}; }

  function void pre_randomize();
    pre_calls++;
  endfunction

  function void post_randomize();
    post_calls++;
  endfunction
endclass

class receiver_holder;
  randomizable_item items[0:0];

  function new();
    items[0] = new;
  endfunction
endclass

module test;
  receiver_holder holder;
  int receiver_evals;

  function int next_index();
    receiver_evals++;
    return 0;
  endfunction

  initial begin
    holder = new;

    if (!holder.items[next_index()].randomize())
      $fatal(1, "plain randomize failed");
    if (receiver_evals != 1 || holder.items[0].pre_calls != 1
        || holder.items[0].post_calls != 1)
      $fatal(1, "plain receiver/hooks: eval=%0d pre=%0d post=%0d",
             receiver_evals, holder.items[0].pre_calls,
             holder.items[0].post_calls);

    void'(holder.items[next_index()].randomize() with { value == 100; });
    if (receiver_evals != 2 || holder.items[0].pre_calls != 2
        || holder.items[0].post_calls != 1)
      $fatal(1, "failed receiver/hooks: eval=%0d pre=%0d post=%0d",
             receiver_evals, holder.items[0].pre_calls,
             holder.items[0].post_calls);

    if (!holder.items[next_index()].randomize(null))
      $fatal(1, "randomize(null) check failed");
    if (receiver_evals != 3 || holder.items[0].pre_calls != 2
        || holder.items[0].post_calls != 1)
      $fatal(1, "null receiver/hooks: eval=%0d pre=%0d post=%0d",
             receiver_evals, holder.items[0].pre_calls,
             holder.items[0].post_calls);

    void'(holder.items[next_index()].randomize() with { value == 7; });
    if (receiver_evals != 4 || holder.items[0].pre_calls != 3
        || holder.items[0].post_calls != 2 || holder.items[0].value != 7)
      $fatal(1, "with receiver/hooks/value: eval=%0d pre=%0d post=%0d value=%0d",
             receiver_evals, holder.items[0].pre_calls,
             holder.items[0].post_calls, holder.items[0].value);

    $display("PASSED");
  end
endmodule
