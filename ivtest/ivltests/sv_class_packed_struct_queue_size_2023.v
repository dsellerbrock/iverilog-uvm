typedef struct packed {
  bit valid;
  bit ready;
} status_t;

class model;
  function bit check();
    status_t q[$];
    string text;
    int by_key[int];

    if (q.size != 0 || q.size() != 0)
      return 0;

    q.push_back('{valid:1'b0, ready:1'b1});
    q.push_back('{valid:1'b1, ready:1'b0});
    if (q.size != 2 || q.size() != 2 || q.size != q.size())
      return 0;

    text = "abc";
    by_key[4] = 10;
    by_key[9] = 11;
    return text.len == text.len() && text.len == 3
           && by_key.num == by_key.num() && by_key.num == 2
           && by_key.size == by_key.size() && by_key.size == 2;
  endfunction
endclass

module main;
  initial begin
    model m;
    m = new;
    if (!m.check())
      $fatal(1, "packed-struct queue size or neighboring method controls failed");
    $display("PASS packed-struct queue size and neighboring controls");
  end
endmodule
