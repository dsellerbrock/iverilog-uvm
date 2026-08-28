// OpenTitan commercial-flow compatibility extension: an ordinary assignment
// between a
// queue and a dynamic array may convert packed integral elements that differ
// only in 2-state versus 4-state representation. IEEE 1800-2017/2023 6.22.2
// and 7.6 otherwise require equivalent element types, so this test also pins
// the deliberately narrow cross-kind boundary.
class byte_order_compat;
  int errors;

  function void check_value(input bit condition, input string what);
    if (!condition) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endfunction

  // This is the source shape used by OpenTitan spi_agent_cfg::swap_byte_order.
  virtual function void swap_byte_order(ref logic [7:0] data[$]);
    bit [7:0] data_arr[];

    data_arr = new[5];
    foreach (data_arr[i]) data_arr[i] = 8'hee;

    data_arr = data;
    check_value(data_arr.size() == 3,
                "queue-to-dynamic-array uses source element count");
    check_value(data_arr[0] == 8'h12,
                "queue-to-dynamic-array preserves known bits");
    check_value(data_arr[1] == 8'h05,
                "queue-to-dynamic-array maps X bits to zero");
    check_value(data_arr[2] == 8'h0a,
                "queue-to-dynamic-array maps Z bits to zero");
    data_arr[data_arr.size()] = 8'hff;
    check_value(data_arr.size() == 3,
                "queue-to-dynamic-array retains dynamic-array kind");

    data[0] = 8'hfe;
    check_value(data_arr[0] == 8'h12,
                "queue-to-dynamic-array is a value copy");

    data_arr[0] = 8'ha5;
    data_arr[1] = 8'h5a;
    data_arr[2] = 8'hff;
    data.delete();
    data.push_back(8'h00);

    data = data_arr;
    check_value(data.size() == 3,
                "dynamic-array-to-queue replaces destination size");
    check_value(data[0] === 8'ha5 && data[1] === 8'h5a
                && data[2] === 8'hff,
                "dynamic-array-to-queue preserves converted elements");
    data.push_back(8'h3c);
    check_value(data.size() == 4 && data[3] === 8'h3c,
                "dynamic-array-to-queue retains queue kind");

    data_arr[0] = 8'h00;
    check_value(data[0] === 8'ha5,
                "dynamic-array-to-queue is a value copy");
  endfunction
endclass

module sv_queue_darray_state_compat;
  logic [7:0] bytes[$];
  logic [7:0] logic_dynamic[];
  logic [7:0] logic_copy_dynamic[];
  bit [7:0] bit_queue[$];
  byte_order_compat probe;

  initial begin
    bytes.push_back(8'h12);
    bytes.push_back(8'hx5);
    bytes.push_back(8'hzA);

    probe = new;
    probe.swap_byte_order(bytes);

    // Exercise the opposite state-converting direction as well. This reaches
    // the destination-typed queue opcode with a 2-state element encoding;
    // the OpenTitan method above reaches its 4-state form on the copy back.
    logic_dynamic = new[3];
    logic_dynamic[0] = 8'h34;
    logic_dynamic[1] = 8'hx6;
    logic_dynamic[2] = 8'hzB;
    bit_queue = '{8'hff, 8'hee, 8'hdd, 8'hcc};

    bit_queue = logic_dynamic;
    probe.check_value(bit_queue.size() == 3,
                      "dynamic-array-to-queue uses source element count");
    probe.check_value(bit_queue[0] == 8'h34,
                      "dynamic-array-to-queue preserves known bits");
    probe.check_value(bit_queue[1] == 8'h06,
                      "dynamic-array-to-queue maps X bits to zero");
    probe.check_value(bit_queue[2] == 8'h0b,
                      "dynamic-array-to-queue maps Z bits to zero");
    logic_dynamic[0] = 8'h00;
    probe.check_value(bit_queue[0] == 8'h34,
                      "dynamic-array-to-queue state conversion is a value copy");

    logic_copy_dynamic = bit_queue;
    probe.check_value(logic_copy_dynamic.size() == 3
                      && logic_copy_dynamic[0] === 8'h34
                      && logic_copy_dynamic[1] === 8'h06
                      && logic_copy_dynamic[2] === 8'h0b,
                      "bit queue converts to a logic dynamic array");
    logic_copy_dynamic[logic_copy_dynamic.size()] = 8'hff;
    probe.check_value(logic_copy_dynamic.size() == 3,
                      "bit-queue-to-dynamic-array retains dynamic-array kind");
    bit_queue.push_back(8'h4d);
    probe.check_value(bit_queue.size() == 4 && bit_queue[3] == 8'h4d,
                      "dynamic-array-to-bit-queue retains queue kind");
    bit_queue[0] = 8'hff;
    probe.check_value(logic_copy_dynamic[0] === 8'h34,
                      "queue-to-dynamic state expansion is a value copy");

    if (probe.errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", probe.errors);
  end
endmodule
