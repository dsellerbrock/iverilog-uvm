// -gcommercial-unsafe still admits only equal-width, equal-signedness packed
// bit/logic elements at whole-container value-copy boundaries. This fixture
// pins the forbidden width, signedness, enum, and ref cases.
module sv_commercial_unsafe_fail;
  logic [7:0] logic_q[$];
  bit [6:0] narrow_d[];

  logic signed [7:0] signed_q[$];
  bit unsigned [7:0] unsigned_d[];

  typedef enum bit [7:0] { ENUM_ZERO = 8'h00 } byte_enum_t;
  byte_enum_t enum_d[];

  task automatic reject_ref(ref bit [7:0] values[$]);
    if (values.size() == -1) $display("unreachable");
  endtask

  task automatic reject_width_input(input bit [6:0] values[$]);
    if (values.size() == -1) $display("unreachable");
  endtask

  task automatic reject_width_output(output bit [6:0] values[$]);
    values.delete();
  endtask

  initial begin
    narrow_d = logic_q;
    unsigned_d = signed_q;
    enum_d = logic_q;
    reject_ref(logic_q);
    reject_width_input(logic_q);
    reject_width_output(logic_q);
  end
endmodule
