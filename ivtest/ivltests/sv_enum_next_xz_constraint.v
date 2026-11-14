typedef enum bit [2:0] { E0, E1, E2, E3, E4, E5, E6 } e7_t;

class enum_step;
  e7_t base = E2;
  logic [31:0] step;
  rand e7_t next_value;
  constraint c_next { next_value == base.next(step); }
endclass

class plain_state;
  logic [31:0] state;
  rand bit [2:0] value;
  constraint c_state { value == state[2:0]; }
endclass

module main;
  enum_step obj;
  plain_state plain;
  initial begin
    obj = new;
    plain = new;
    obj.next_value = E0;
    obj.step = 'x;
    $display("x step rc=%0d next=%s", obj.randomize(), obj.next_value.name());
    obj.step = 32'h0000_000z;
    $display("z step rc=%0d next=%s", obj.randomize(), obj.next_value.name());
    obj.step = 3;
    $display("2-state step rc=%0d next=%s", obj.randomize(), obj.next_value.name());
    plain.state = 'x;
    $display("plain state read rc=%0d value=%0d", plain.randomize(), plain.value);
  end
endmodule
