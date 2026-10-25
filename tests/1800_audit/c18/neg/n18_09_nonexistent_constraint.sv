// IEEE 1800-2017 §18.9 p. 534; IEEE 1800-2023 §18.9 p. 556.
class Item;
  rand int x;
  constraint c1 { x > 0; }
endclass

module test;
  initial begin
    Item it = new;
    it.nonexistent_c.constraint_mode(0);
  end
endmodule
