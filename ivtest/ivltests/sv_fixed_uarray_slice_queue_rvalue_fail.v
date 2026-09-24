// Each assignment must fail for its own 7.4.6/7.6 reason in both editions.
class holder_t;
  bit [7:0] descending[8:1];
  local bit [7:0] hidden[8:1];
endclass

module test;
  holder_t holder;
  bit [7:0] packed_word;
  bit [7:0] q[$];
  string strings[$];
  int base;
  initial begin
    holder = new;
    q = holder.descending[4:6];
    q = holder.descending[9:8];
    q = holder.descending[base +: 2];
    q = holder.descending[6 +: 0];
    strings = holder.descending[6:4];
    q = packed_word[6:4];
    q = holder.hidden[6:4];
  end
endmodule
