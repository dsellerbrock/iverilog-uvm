typedef union { bit [7:0] byte_value; int word_value; } union_t;

class bad_rand_union;
  rand union_t value;
endclass

module sv_rand_unpacked_union_fail;
  bad_rand_union item;
  initial begin
    item = new;
    void'(item.randomize());
    $finish;
  end
endmodule
