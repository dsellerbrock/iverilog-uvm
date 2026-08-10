// IEEE 1800-2017 6.19.4: every numerical use of an enum converts it
// to its base integral type. Compound assignments and increment/decrement
// therefore require an explicit cast before storing their result into an enum.
module sv_enum_compound_assignment_fail;
  typedef enum int { A = 1, B = 2, AB = 3 } enum_t;

  class Holder;
    enum_t value;
  endclass

  enum_t value;
  enum_t values[2];
  Holder holder;
  int sink;

  initial begin
    holder = new;
    value += 1;
    value <<= 1;
    value &= B;
    value++;
    --value;
    values[0] ^= B;
    holder.value |= B;
    sink = value++;
    sink = --value;
  end
endmodule
