// Near misses for the OpenTitan commercial-flow cross-kind bit/logic compatibility
// extension. IEEE 1800-2017/2023 6.22.2 and 6.22.3 retain their matching- and
// equivalent-type requirements, while 7.6 requires equivalent element types
// for array assignment. The extension is therefore confined to ordinary
// blocking assignment between a queue and a dynamic array: width, signedness,
// enum identity, same-kind assignment, initialization and formal binding stay
// strict.
module sv_queue_darray_state_compat_fail;
  logic [7:0] width_q[$];
  bit [6:0] width_d[];

  logic signed [7:0] signed_q[$];
  bit unsigned [7:0] unsigned_d[];

  typedef enum bit [7:0] { ENUM_ZERO = 8'h00 } byte_enum_t;
  logic [7:0] plain_q[$];
  byte_enum_t enum_d[];

  logic [7:0] logic_q[$];
  bit [7:0] bit_q[$];
  logic [7:0] logic_d[];
  bit [7:0] bit_d[];

  chandle chandle_q[$];
  logic [63:0] logic64_d[];
  logic [63:0] logic64_q[$];
  chandle chandle_d[];

  task automatic reject_initializer;
    bit [7:0] initialized_d[] = logic_q;
  endtask

  task automatic reject_ref(ref bit [7:0] formal_d[]);
    if (formal_d.size() == -1) $display("unreachable");
  endtask

  task automatic reject_input(input bit [7:0] formal_d[]);
    if (formal_d.size() == -1) $display("unreachable");
  endtask

  initial begin
    width_d = width_q;
    unsigned_d = signed_q;
    enum_d = plain_q;

    bit_q = logic_q;
    logic_q = bit_q;
    bit_d = logic_d;
    logic_d = bit_d;

    logic64_d = chandle_q;
    chandle_d = logic64_q;

    reject_initializer();
    reject_ref(logic_q);
    reject_input(logic_q);
  end
endmodule
