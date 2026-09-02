// IEEE 1800-2017/2023 6.22.1 and 25.9: queue upper bounds do not make
// otherwise equivalent queue types nonmatching, but each concrete interface
// specialization retains the exact bound of its physical member. Mutation
// through a matching VIF, including a VIF stored in a class property, follows
// the bound of the live physical interface rather than the VIF declaration.
typedef int queue_bound_2_t[$:2];
typedef int queue_bound_4_t[$:4];
typedef queue_bound_2_t assoc_queue_bound_2_t[int];
typedef queue_bound_4_t assoc_queue_bound_4_t[int];
typedef queue_bound_2_t darray_queue_bound_2_t[];
typedef queue_bound_4_t darray_queue_bound_4_t[];
typedef int unbounded_queue_t[$];
typedef darray_queue_bound_2_t queue_darray_queue_bound_2_t[$];
typedef darray_queue_bound_4_t queue_darray_queue_bound_4_t[$];
typedef assoc_queue_bound_2_t queue_assoc_queue_bound_2_t[$];
typedef assoc_queue_bound_4_t queue_assoc_queue_bound_4_t[$];

interface queue_bound_if #(type T = int);
  T q;
endinterface

class queue_bound_holder;
  virtual queue_bound_if #(queue_bound_2_t) vif;
endclass

class queue_index_holder;
  int d[];
endclass

module sv_vif_parameter_specialization_queue_bound_layout;
  queue_bound_if #(queue_bound_2_t) physical_2();
  queue_bound_if #(queue_bound_4_t) physical_4();
  queue_bound_if #(queue_bound_4_t) physical_nested_4();
  queue_bound_if #(assoc_queue_bound_2_t) physical_assoc_2();
  queue_bound_if #(assoc_queue_bound_4_t) physical_assoc_4();
  queue_bound_if #(darray_queue_bound_2_t) physical_darray_2();
  queue_bound_if #(darray_queue_bound_4_t) physical_darray_4();

  virtual queue_bound_if #(queue_bound_2_t) vif_to_4;
  virtual queue_bound_if #(queue_bound_4_t) vif_to_2;
  virtual queue_bound_if #(assoc_queue_bound_2_t) assoc_vif_to_4;
  virtual queue_bound_if #(assoc_queue_bound_4_t) assoc_vif_to_2;
  virtual queue_bound_if #(darray_queue_bound_2_t) darray_vif_to_4;
  virtual queue_bound_if #(darray_queue_bound_4_t) darray_vif_to_2;
  queue_bound_holder holder;
  queue_index_holder index_holder;

  unbounded_queue_t unbounded_q;
  queue_bound_2_t bounded_source_q;
  queue_darray_queue_bound_2_t deep_qdq_2;
  queue_darray_queue_bound_4_t deep_qdq_4;
  darray_queue_bound_4_t deep_dq_value_4;
  queue_assoc_queue_bound_2_t deep_qaq_2;
  queue_assoc_queue_bound_4_t deep_qaq_4;
  assoc_queue_bound_4_t deep_aq_value_4;
  queue_bound_2_t fixed_q_2[0:0];
  darray_queue_bound_2_t fixed_dq_2[0:0];
  assoc_queue_bound_2_t fixed_aq_2[0:0];
  int copy_src[][];
  int copy_dst[][];
  int wide_darray[];
  int wide_queue[$];
  longint unsigned wide_index;

  initial begin
    // The concrete layouts remain independent even though the queue types
    // match: [$:2] holds three elements and [$:4] holds five.
    physical_2.q.push_back(1);
    physical_2.q.push_back(2);
    physical_2.q.push_back(3);
    physical_2.q.push_back(4);
    physical_4.q.push_back(1);
    physical_4.q.push_back(2);
    physical_4.q.push_back(3);
    physical_4.q.push_back(4);
    physical_4.q.push_back(5);
    if (physical_2.q.size() != 3 || physical_4.q.size() != 5)
      $fatal(1, "concrete bounded-queue layouts aliased");

    physical_2.q.delete();
    physical_4.q.delete();
    vif_to_4 = physical_4;
    vif_to_2 = physical_2;

    // Static [$:2] VIF -> physical [$:4] must retain five.
    vif_to_4.q.push_back(11);
    vif_to_4.q.push_back(12);
    vif_to_4.q.push_back(13);
    vif_to_4.q.push_back(14);
    vif_to_4.q.push_back(15);
    // Static [$:4] VIF -> physical [$:2] must cap at three.
    vif_to_2.q.push_back(21);
    vif_to_2.q.push_back(22);
    vif_to_2.q.push_back(23);
    vif_to_2.q.push_back(24);
    if (vif_to_4.q.size() != 5 || physical_4.q.size() != 5)
      $fatal(1, "VIF declaration bound truncated physical [$:4] queue");
    if (vif_to_2.q.size() != 3 || physical_2.q.size() != 3)
      $fatal(1, "VIF declaration bound overran physical [$:2] queue");

    // Whole-queue assignment copies values but cannot replace the destination
    // declaration's exact bound metadata. Check both directions, then mutate
    // through a matching VIF so the live physical metadata is authoritative.
    physical_2.q.delete();
    physical_4.q.delete();
    physical_4.q.push_back(41);
    physical_4.q.push_back(42);
    physical_4.q.push_back(43);
    physical_4.q.push_back(44);
    physical_4.q.push_back(45);
    vif_to_2.q = physical_4.q;
    if (physical_2.q.size() != 3 || physical_2.q[0] != 41
        || physical_2.q[1] != 42 || physical_2.q[2] != 43)
      $fatal(1, "Q4-to-Q2 assignment did not truncate to destination bound");
    vif_to_2.q[vif_to_2.q.size()] = 46;
    if (physical_2.q.size() != 3)
      $fatal(1, "Q4 source bound contaminated Q2 destination metadata");

    vif_to_4.q = physical_2.q;
    if (physical_4.q.size() != 3)
      $fatal(1, "Q2-to-Q4 assignment copied the wrong contents");
    vif_to_4.q[vif_to_4.q.size()] = 47;
    vif_to_4.q[vif_to_4.q.size()] = 48;
    if (physical_4.q.size() != 5 || physical_4.q[3] != 47
        || physical_4.q[4] != 48)
      $fatal(1, "Q2 source bound contaminated Q4 destination metadata");

    // UVM-style holder path: the queue receiver's provenance root is HOLDER,
    // so this proves the exact bound travels with the live member value.
    holder = new;
    holder.vif = physical_nested_4;
    holder.vif.q.push_back(31);
    holder.vif.q.push_back(32);
    holder.vif.q.push_back(33);
    holder.vif.q.push_back(34);
    holder.vif.q.push_back(35);
    if (holder.vif.q.size() != 5 || physical_nested_4.q.size() != 5)
      $fatal(1, "nested-holder VIF truncated physical [$:4] queue");

    // A missing associative element is vivified as a queue. Its bound comes
    // from the physical outer member, not the matching VIF's nested typedef.
    assoc_vif_to_4 = physical_assoc_4;
    assoc_vif_to_2 = physical_assoc_2;
    assoc_vif_to_4.q[1].push_back(101);
    assoc_vif_to_4.q[1].push_back(102);
    assoc_vif_to_4.q[1][assoc_vif_to_4.q[1].size()] = 103;
    assoc_vif_to_4.q[1].insert(1, 104);
    assoc_vif_to_4.q[1].push_front(100);
    if (physical_assoc_4.q[1].size() != 5
        || physical_assoc_4.q[1][0] != 100
        || physical_assoc_4.q[1][4] != 103)
      $fatal(1, "associative carrier lost physical nested Q4 bound");

    assoc_vif_to_2.q[1].push_back(201);
    assoc_vif_to_2.q[1].push_back(202);
    assoc_vif_to_2.q[1].push_back(203);
    assoc_vif_to_2.q[1].insert(1, 204);
    assoc_vif_to_2.q[1].push_front(200);
    if (physical_assoc_2.q[1].size() != 3
        || physical_assoc_2.q[1][0] != 200
        || physical_assoc_2.q[1][1] != 201)
      $fatal(1, "associative carrier lost physical nested Q2 bound");

    // The same immediate child-bound carrier is required for a dynamic-array
    // outer value; new[1] creates a nil queue slot that the first mutation
    // must vivify with the physical declaration's nested queue capacity.
    physical_darray_4.q = new[1];
    physical_darray_2.q = new[1];
    darray_vif_to_4 = physical_darray_4;
    darray_vif_to_2 = physical_darray_2;
    darray_vif_to_4.q[0].push_back(301);
    darray_vif_to_4.q[0].push_back(302);
    darray_vif_to_4.q[0][darray_vif_to_4.q[0].size()] = 303;
    darray_vif_to_4.q[0].insert(1, 304);
    darray_vif_to_4.q[0].push_front(300);
    if (physical_darray_4.q[0].size() != 5
        || physical_darray_4.q[0][0] != 300
        || physical_darray_4.q[0][4] != 303)
      $fatal(1, "dynamic-array carrier lost physical nested Q4 bound");

    darray_vif_to_2.q[0].push_back(401);
    darray_vif_to_2.q[0].push_back(402);
    darray_vif_to_2.q[0].push_back(403);
    darray_vif_to_2.q[0].insert(1, 404);
    darray_vif_to_2.q[0].push_front(400);
    if (physical_darray_2.q[0].size() != 3
        || physical_darray_2.q[0][0] != 400
        || physical_darray_2.q[0][1] != 401)
      $fatal(1, "dynamic-array carrier lost physical nested Q2 bound");

    // Rebinding a copied A or D value must trim every already-populated
    // nested queue to the destination declaration, without mutating source.
    physical_assoc_2.q.delete();
    physical_assoc_4.q.delete();
    physical_assoc_4.q[7].push_back(501);
    physical_assoc_4.q[7].push_back(502);
    physical_assoc_4.q[7].push_back(503);
    physical_assoc_4.q[7].push_back(504);
    physical_assoc_4.q[7].push_back(505);
    physical_assoc_2.q = physical_assoc_4.q;
    if (physical_assoc_2.q[7].size() != 3
        || physical_assoc_4.q[7].size() != 5)
      $fatal(1, "populated A-to-Q copy did not apply destination tail bound");

    physical_darray_2.q = new[1];
    physical_darray_4.q = new[1];
    physical_darray_4.q[0].push_back(511);
    physical_darray_4.q[0].push_back(512);
    physical_darray_4.q[0].push_back(513);
    physical_darray_4.q[0].push_back(514);
    physical_darray_4.q[0].push_back(515);
    physical_darray_2.q = physical_darray_4.q;
    if (physical_darray_2.q[0].size() != 3
        || physical_darray_4.q[0].size() != 5)
      $fatal(1, "populated D-to-Q copy did not apply destination tail bound");

    // Depth-three Q<D<Q>> and Q<A<Q>> copies exercise recursive descendant
    // rebinding when the outer queue itself is unbounded and needs no trim.
    deep_dq_value_4 = new[1];
    deep_dq_value_4[0].push_back(521);
    deep_dq_value_4[0].push_back(522);
    deep_dq_value_4[0].push_back(523);
    deep_dq_value_4[0].push_back(524);
    deep_dq_value_4[0].push_back(525);
    deep_qdq_4.push_back(deep_dq_value_4);
    deep_qdq_2 = deep_qdq_4;
    if (deep_qdq_2[0][0].size() != 3
        || deep_qdq_4[0][0].size() != 5)
      $fatal(1, "Q<D<Q>> copy did not recursively enforce destination bound");

    deep_aq_value_4[9].push_back(531);
    deep_aq_value_4[9].push_back(532);
    deep_aq_value_4[9].push_back(533);
    deep_aq_value_4[9].push_back(534);
    deep_aq_value_4[9].push_back(535);
    deep_qaq_4.push_back(deep_aq_value_4);
    deep_qaq_2 = deep_qaq_4;
    if (deep_qaq_2[0][9].size() != 3
        || deep_qaq_4[0][9].size() != 5)
      $fatal(1, "Q<A<Q>> copy did not recursively enforce destination bound");

    // Q0 is a known-unbounded destination, not absent metadata. A bounded
    // source assignment must not contaminate later destination mutations.
    bounded_source_q.push_back(541);
    bounded_source_q.push_back(542);
    bounded_source_q.push_back(543);
    unbounded_q = bounded_source_q;
    unbounded_q.push_back(544);
    unbounded_q.push_front(540);
    if (unbounded_q.size() != 5 || unbounded_q[0] != 540
        || unbounded_q[4] != 544)
      $fatal(1, "known-unbounded Q0 destination inherited source bound");

    // Fixed unpacked object slots have no object-signal functor. Their array
    // declaration must carry Q/D/A layout and stamp a lazily created slot.
    fixed_q_2[0].push_back(601);
    fixed_q_2[0].push_back(602);
    fixed_q_2[0].push_back(603);
    fixed_q_2[0].push_back(604);
    if (fixed_q_2[0].size() != 3)
      $fatal(1, "fixed-array queue slot lost Q bound");

    fixed_dq_2[0] = new[1];
    fixed_dq_2[0][0].push_back(701);
    fixed_dq_2[0][0].push_back(702);
    fixed_dq_2[0][0].push_back(703);
    fixed_dq_2[0][0].push_back(704);
    if (fixed_dq_2[0][0].size() != 3)
      $fatal(1, "fixed-array D<Q> slot lost recursive bound");

    fixed_aq_2[0][1].push_back(801);
    fixed_aq_2[0][1].push_back(802);
    fixed_aq_2[0][1].push_back(803);
    fixed_aq_2[0][1].push_back(804);
    if (fixed_aq_2[0][1].size() != 3)
      $fatal(1, "fixed-array A<Q> slot lost recursive bound");

    // new[n](source) copies nested dynamic arrays as values, rather than
    // aliasing an inner container through shallow object-handle assignment.
    copy_src = new[1];
    copy_src[0] = new[1];
    copy_src[0][0] = 901;
    copy_dst = new[1](copy_src);
    copy_dst[0][0] = 902;
    if (copy_src[0][0] != 901 || copy_dst[0][0] != 902)
      $fatal(1, "new[n](source) aliased nested dynamic-array value");

    // The runtime element API is unsigned today. A legal 64-bit selector
    // above UINT_MAX must be rejected before narrowing, for both signal and
    // object/property paths; reads return the container element default.
    wide_index = 64'h1_0000_0000;
    wide_darray = new[1];
    wide_darray[0] = 911;
    wide_darray[wide_index] = 912;
    if (wide_darray[0] != 911 || wide_darray[wide_index] !== 0)
      $fatal(1, "wide dynamic-array index wrapped to element zero");

    wide_queue.push_back(921);
    wide_queue[wide_index] = 922;
    if (wide_queue[0] != 921 || wide_queue[wide_index] !== 0)
      $fatal(1, "wide queue index wrapped to element zero");

    index_holder = new;
    index_holder.d = new[1];
    index_holder.d[0] = 931;
    if (index_holder.d[wide_index] !== 0)
      $fatal(1, "wide class-property darray read wrapped to element zero");

    $display("PASSED");
  end
endmodule
