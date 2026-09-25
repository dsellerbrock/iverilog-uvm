// IEEE 1800-2017/2023 7.6, 13.5.1, 25.9: a selected virtual-interface
// task receives a fixed unpacked input array by value in declared order.
typedef struct packed {
  bit read_lock;
  bit write_lock;
} vif_lock_t;

interface vif_fixed_input_if;
  int calls;
  bit [5:0] seen;
  int logic_calls;
  logic [11:0] logic_seen;
  int static_calls;
  logic [15:0] static_seen;

  task automatic consume(input vif_lock_t value[0:2]);
    calls++;
    seen = {value[0], value[1], value[2]};
    value[0] = '0;
  endtask

  task automatic consume_logic(input logic [3:0] value[2:0]);
    logic_calls++;
    logic_seen = {value[2], value[1], value[0]};
    value[2] = '0;
  endtask

  task consume_static(input logic [3:0] first[0:1],
                      input logic [3:0] second[1:0]);
    static_calls++;
    static_seen = {first[0], first[1], second[1], second[0]};
    first[0] = '0;
    second[1] = '0;
  endtask

  task automatic take_out(output vif_lock_t value[0:2]);
    value[0] = '0;
  endtask

  task automatic take_inout(inout vif_lock_t value[0:2]);
    value[0] = '0;
  endtask

  task automatic take_ref(ref vif_lock_t value[0:2]);
    value[0] = '0;
  endtask
endinterface
