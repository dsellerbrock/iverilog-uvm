// Destination-typed queue/dynamic-array conversion inside object builders.
// These stores do not have a signal declaration at runtime, so assignment-
// pattern lowering must materialize each nested value in its destination kind.
// Use IEEE-equivalent real elements here: the intentionally narrow bit/logic
// compatibility extension remains confined to ordinary whole assignments and
// must not be widened to assignment-pattern member contexts.
typedef struct {
  real q[$];
  real d[];
} container_aggregate_t;

module sv_container_cross_kind_builders;
  int errors;
  real source_d[];
  real source_q[$];
  real source_queues[$][$];
  real source_darrays[$][];
  real queue_of_queues[$][$];
  real queue_of_darrays[$][];
  real deep_source[$][$][$];
  real true_queues[$][$];
  real false_queues[$][$];
  real fixed_pair[2];
  real fixed_matrix[2][3];
  bit choose_true;
  container_aggregate_t aggregate_value;

  task check(input bit condition, input string what);
    if (!condition) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    source_d = new[2];
    source_d[0] = 2.0;
    source_d[1] = 4.0;
    source_q.push_back(6.0);
    source_q.push_back(8.0);

    // A collection-valued pattern item is one element when its type is the
    // destination element type. The inner destination kind must still win.
    queue_of_queues = '{source_d};
    source_d[0] = 20.0;
    queue_of_queues[0].push_back(10.0);
    check(queue_of_queues.size() == 1
          && queue_of_queues[0].size() == 3
          && queue_of_queues[0][0] == 2.0
          && queue_of_queues[0][2] == 10.0,
          "queue pattern item converts darray to independent queue");

    // A collection operand splices its members. The typed object-splice
    // opcode must retain value semantics while materializing each member in
    // the declared destination element type.
    source_darrays = '{source_d};
    queue_of_queues = '{source_darrays[0]};
    queue_of_queues[0].push_back(11.0);
    check(queue_of_queues[0].size() == 3
          && queue_of_queues[0][0] == 20.0
          && queue_of_queues[0][2] == 11.0,
          "selected darray pattern item converts to queue");

    queue_of_queues = {source_darrays};
    source_darrays[0][0] = 200.0;
    queue_of_queues[0].push_back(12.0);
    check(queue_of_queues.size() == 1
          && queue_of_queues[0].size() == 3
          && queue_of_queues[0][0] == 20.0
          && queue_of_queues[0][2] == 12.0,
          "object splice converts each darray member to an independent queue");

    queue_of_darrays = '{source_q};
    source_q[0] = 60.0;
    queue_of_darrays[0][2] = 14.0;
    check(queue_of_darrays.size() == 1
          && queue_of_darrays[0].size() == 2
          && queue_of_darrays[0][0] == 6.0,
          "queue pattern item converts queue to independent darray");

    source_queues = queue_of_queues;
    queue_of_darrays = {source_queues};
    source_queues[0][0] = 200.0;
    queue_of_darrays[0][3] = 14.0;
    check(queue_of_darrays.size() == 1
          && queue_of_darrays[0].size() == 3
          && queue_of_darrays[0][0] == 20.0,
          "object splice converts each queue member to an independent darray");

    // Preserve an index on a collection-valued splice operand. Distinct
    // outer values make lowering the whole source instead of deep_source[1]
    // observably wrong.
    deep_source = '{'{'{1.0}, '{2.0, 3.0}},
                    '{'{11.0, 12.0}, '{21.0}}};
    queue_of_darrays = {deep_source[1]};
    check(queue_of_darrays.size() == 2
          && queue_of_darrays[0].size() == 2
          && queue_of_darrays[0][0] == 11.0
          && queue_of_darrays[0][1] == 12.0
          && queue_of_darrays[1].size() == 1
          && queue_of_darrays[1][0] == 21.0,
          "selected object splice retains its source index");

    // Once another index selects one inner queue, that queue is one
    // assignment-compatible destination element rather than a collection
    // whose real-valued members should be spliced into the outer result.
    queue_of_darrays = {deep_source[1][0]};
    check(queue_of_darrays.size() == 1
          && queue_of_darrays[0].size() == 2
          && queue_of_darrays[0][0] == 11.0
          && queue_of_darrays[0][1] == 12.0,
          "multi-index container item uses its exact selected type");

    fixed_pair = '{51.0, 52.0};
    queue_of_darrays = {fixed_pair};
    check(queue_of_darrays.size() == 1
          && queue_of_darrays[0].size() == 2
          && queue_of_darrays[0][0] == 51.0
          && queue_of_darrays[0][1] == 52.0,
          "fixed array item converts to one dynamic-array element");

    // For a multidimensional fixed-array item, 10.10 examines the element
    // type of its slowest-varying dimension. Each fixed_matrix row is one
    // fixed[3] value and is assignment-compatible with a real dynamic array.
    foreach (fixed_matrix[i,j])
      fixed_matrix[i][j] = 60.0 + 10.0*i + j;
    queue_of_darrays = {fixed_matrix};
    check(queue_of_darrays.size() == 2
          && queue_of_darrays[0].size() == 3
          && queue_of_darrays[0][0] == 60.0
          && queue_of_darrays[0][2] == 62.0
          && queue_of_darrays[1].size() == 3
          && queue_of_darrays[1][0] == 70.0
          && queue_of_darrays[1][2] == 72.0,
          "multidimensional fixed item splices slowest-dimension elements");

    // A conditional is still one collection splice operand. Both constant
    // and runtime conditions must retain the destination-element context in
    // their arms (IEEE 1800-2017/2023 10.10 and 11.4.11).
    true_queues = '{'{31.0, 32.0}, '{33.0}};
    false_queues = '{'{41.0}, '{42.0, 43.0}};
    queue_of_darrays = {1'b1 ? true_queues : false_queues};
    check(queue_of_darrays.size() == 2
          && queue_of_darrays[0].size() == 2
          && queue_of_darrays[0][0] == 31.0
          && queue_of_darrays[1].size() == 1
          && queue_of_darrays[1][0] == 33.0,
          "constant conditional splice retains destination element type");

    choose_true = 1'b0;
    queue_of_darrays = {choose_true ? true_queues : false_queues};
    check(queue_of_darrays.size() == 2
          && queue_of_darrays[0].size() == 1
          && queue_of_darrays[0][0] == 41.0
          && queue_of_darrays[1].size() == 2
          && queue_of_darrays[1][1] == 43.0,
          "runtime conditional splice retains destination element type");

    // An unpacked aggregate is built as a cobject. Its object-backed members
    // need the same destination conversion before %store/prop/obj.
    aggregate_value = '{source_d, source_q};
    source_d[1] = 40.0;
    source_q[1] = 80.0;
    aggregate_value.q.push_back(16.0);
    aggregate_value.d[2] = 18.0;
    check(aggregate_value.q.size() == 3
          && aggregate_value.q[1] == 4.0
          && aggregate_value.q[2] == 16.0,
          "aggregate queue member has destination kind and value semantics");
    check(aggregate_value.d.size() == 2
          && aggregate_value.d[1] == 8.0,
          "aggregate darray member has destination kind and value semantics");

    queue_of_queues = '{aggregate_value.d};
    queue_of_queues[0].push_back(18.0);
    check(queue_of_queues[0].size() == 3
          && queue_of_queues[0][0] == 60.0
          && queue_of_queues[0][2] == 18.0,
          "property darray pattern item converts to queue");

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
