class queue_holder;
  logic [7:0] data[$];
endclass

module test;
  queue_holder item;
  logic [7:0] first;
  logic [7:0] second;
  logic [7:0] last;
  logic [7:0] empty;

  function automatic logic [7:0] identity(logic [7:0] value);
    return value;
  endfunction

  initial begin
    item = new;
    item.data.push_back(8'hx3);
    item.data.push_back(8'h34);

    first = identity(item.data.pop_front);
    if (first !== 8'hx3 || item.data.size() != 1 ||
        item.data[0] !== 8'h34)
      $fatal(1, "parenthesis-free pop_front lost result or side effect");

    second = item.data.pop_front();
    if (second !== 8'h34 || item.data.size() != 0)
      $fatal(1, "parenthesized pop_front control failed");

    item.data.push_back(8'ha5);
    last = identity(item.data.pop_back);
    if (last !== 8'ha5 || item.data.size() != 0)
      $fatal(1, "parenthesis-free pop_back lost result or side effect");

    empty = item.data.pop_front;
    if (empty !== 8'hxx || item.data.size() != 0)
      $fatal(1, "empty pop_front changed result or queue");

    $display("PASSED");
  end
endmodule
