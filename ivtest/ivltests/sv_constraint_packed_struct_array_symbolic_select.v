// IEEE 1800-2017/2023 7.4.1, 11.5.1, 18.3: an in-range runtime index
// selects a packed-struct element as part of a class constraint.
typedef struct packed { logic [1:0] value; } packed_word_t;
typedef struct packed { packed_word_t [1:0] words; } packed_holder_t;

class packed_selection_item;
  rand packed_holder_t holder;
  rand bit [1:0] index;
  constraint selected_word { holder.words[index].value == 2'b10; }
endclass

module test;
  initial begin
    packed_selection_item item;
    item = new;

    if (!item.randomize() with { index == 0; })
      $fatal(1, "symbolic packed selection at index 0 failed");
    if (item.holder.words[0].value !== 2'b10)
      $fatal(1, "selected packed word 0 was not constrained");

    if (!item.randomize() with { index == 1; })
      $fatal(1, "symbolic packed selection at index 1 failed");
    if (item.holder.words[1].value !== 2'b10)
      $fatal(1, "selected packed word 1 was not constrained");

    if (item.randomize() with { index == 2; })
      $fatal(1, "out-of-range packed selection unexpectedly succeeded");

    $display("PASSED");
  end
endmodule
