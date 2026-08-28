// IEEE 1800-2017/2023 7.6: equivalent-element queue/dynamic-array
// assignments copy the value into the destination's declared container kind.
// Exercise signal, property and nested object-backed stores; empty/size-only
// tests cannot distinguish the source and destination runtime flavors.
typedef struct {
  int value;
} payload_t;

class real_container_box;
  real q[$];
  real d[];
endclass

class mixed_state_container_box;
  bit [7:0] d[];
endclass

class payload_container_box;
  payload_t q[$];
endclass

class associative_container_box;
  real q_by_key[int][$];
endclass

module sv_container_cross_kind_destination;
  int errors;
  real source_d[];
  real source_q[$];
  real signal_d[];
  real inner_q[$];
  real queue_of_queues[$][$];
  real_container_box box;
  logic [7:0] logic_source_q[$];
  bit [7:0] bit_source_d[];
  logic [7:0] logic_inner_q[$];
  logic [7:0] logic_queue_of_queues[$][$];
  mixed_state_container_box mixed_box;
  payload_t payload_source_d[];
  payload_container_box payload_box;
  real direct_q_by_key[int][$];
  associative_container_box associative_box;
  int target_index_calls;

  task check(input bit condition, input string what);
    if (!condition) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  // IEEE 1800-2017/2023 10.4.1 evaluates this blocking-assignment target
  // expression once. Counting it also catches a lowering path that recomputes
  // the selected nested destination after evaluating the container RHS.
  function int counted_target_index();
    target_index_calls++;
    return 0;
  endfunction

  initial begin
    source_d = new[2];
    source_d[0] = 2.0;
    source_d[1] = 4.0;
    source_q.push_back(6.0);
    source_q.push_back(8.0);

    // A dynamic-array destination must not retain a queue object.
    signal_d = source_q;
    source_q[0] = 60.0;
    check(signal_d.size() == 2 && signal_d[0] == 6.0,
          "signal queue-to-darray value copy");

    box = new;
    box.q = source_d;
    box.q.push_back(6.0);
    source_d[0] = 20.0;
    check(box.q.size() == 3 && box.q[0] == 2.0 && box.q[2] == 6.0,
          "queue property keeps queue methods and value semantics");

    box.d = source_q;
    source_q[1] = 80.0;
    check(box.d.size() == 2 && box.d[1] == 8.0,
          "dynamic-array property is an independent value");

    queue_of_queues.push_back(inner_q);
    queue_of_queues[0] = source_d;
    queue_of_queues[0].push_back(10.0);
    check(queue_of_queues[0].size() == 3
          && queue_of_queues[0][2] == 10.0,
          "nested queue destination keeps queue runtime kind");

    // An associative-array element store is another object-backed boundary:
    // the map copies its value, but only target lowering knows that this
    // element is declared as a queue rather than a dynamic array. Exercise
    // both signal-backed and class-property maps.
    direct_q_by_key[7] = source_d;
    direct_q_by_key[7].push_back(12.0);
    check(direct_q_by_key[7].size() == 3
          && direct_q_by_key[7][2] == 12.0,
          "associative signal element keeps queue runtime kind");

    associative_box = new;
    associative_box.q_by_key[9] = source_d;
    associative_box.q_by_key[9].push_back(14.0);
    check(associative_box.q_by_key[9].size() == 3
          && associative_box.q_by_key[9][2] == 14.0,
          "associative property element keeps queue runtime kind");

    // This mixed-state behavior is the deliberately narrow compatibility
    // extension, not IEEE 1800-2017/2023 6.22.2 or 7.6 equivalence: only a
    // queue/dynamic-array kind change with otherwise matching packed integral
    // elements converts logic to bit. A whole property target must still
    // become its declared dynamic-array kind, with X/Z converted to zero.
    logic_source_q.push_back(8'hx5);
    logic_source_q.push_back(8'hzA);
    mixed_box = new;
    mixed_box.d = logic_source_q;
    check(mixed_box.d.size() == 2
          && mixed_box.d[0] == 8'h05 && mixed_box.d[1] == 8'h0a,
          "mixed-state property target converts X/Z and keeps darray kind");

    // The reverse state direction uses the same narrow extension. The nested
    // destination is a queue and its side-effecting index is evaluated once,
    // as required for the single blocking assignment (10.4.1).
    bit_source_d = new[1];
    bit_source_d[0] = 8'ha5;
    logic_queue_of_queues.push_back(logic_inner_q);
    logic_queue_of_queues[counted_target_index()] = bit_source_d;
    logic_queue_of_queues[0].push_back(8'h5a);
    check(target_index_calls == 1
          && logic_queue_of_queues[0].size() == 2
          && logic_queue_of_queues[0][0] === 8'ha5
          && logic_queue_of_queues[0][1] === 8'h5a,
          "mixed-state nested queue target evaluates its index once");

    // Unpacked structs have value semantics (IEEE 1800-2017/2023 7.2), and
    // equivalent-element queue/darray assignment is covered by 7.6. new[1]
    // leaves the object-backed source slot initially unmaterialized; after the
    // cross-kind copy, the destination declaration's prototype must make this
    // member write create an independent payload value rather than disappear.
    payload_source_d = new[1];
    payload_box = new;
    payload_box.q = payload_source_d;
    payload_box.q[0].value = 42;
    check(payload_box.q.size() == 1 && payload_box.q[0].value == 42
          && payload_source_d[0].value == 0,
          "cross-kind object container keeps destination element prototype");

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
