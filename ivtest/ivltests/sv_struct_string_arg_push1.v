typedef struct {
  string name;
  string regex;
} pair_t;

class holder;
  pair_t items[$];

  function void push_one(pair_t item);
    items.push_back(item);
  endfunction
endclass

module test;
  initial begin
    holder h;
    h = new;
    h.push_one('{"hello", "world"});
    if (h.items.size() != 1) begin
      $display("FAIL size=%0d", h.items.size());
      $finish(1);
    end
    if (h.items[0].name != "hello") begin
      $display("FAIL name=%s", h.items[0].name);
      $finish(1);
    end
    if (h.items[0].regex != "world") begin
      $display("FAIL regex=%s", h.items[0].regex);
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
