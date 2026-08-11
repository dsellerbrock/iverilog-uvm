// Bare parameterized class names in declarations denote the default
// specialization C#().  Exercise late forward resolution, mutual recursion,
// exact typedef provenance, explicit overrides, and container wrappers.

typedef class later_item;

class forward_holder #(int UNUSED = 0);
  later_item item;
endclass

class later_item #(int W = 8);
  bit [W-1:0] payload;
endclass

typedef class mutual_b;

class mutual_a #(int W = 8);
  mutual_b b;
endclass

class mutual_b #(int W = 8);
  mutual_a a;
endclass

class container_item #(int W = 8);
  bit [W-1:0] payload;
endclass

typedef container_item container_queue_t[$];
typedef container_item container_dynamic_t[];

package alias_pkg;
  class collision #(int W = 99);
    bit [W-1:0] payload;
  endclass
endpackage

class alias_target #(int W = 7);
  bit [W-1:0] payload;
endclass

// A nested parameterized forward type must be resolved before the outer
// specialization is cached. Otherwise the early default pool<int>
// specialization can be reused for pool<forward_event<object>> even though
// both results are class types.
class forward_nested_object;
  bit marker;
endclass

typedef class forward_nested_event;

class forward_nested_pool #(type T = int);
  T item;
  virtual function T get();
    return item;
  endfunction
endclass

class forward_nested_early_default;
  forward_nested_pool pool;
endclass

typedef forward_nested_pool#(
  forward_nested_event#(forward_nested_object)
) forward_nested_pool_t;

class forward_nested_holder;
  forward_nested_pool_t pool;
endclass

class forward_nested_event #(type T = int);
  T payload;
endclass

module sv_param_class_bare_forward_identity;
  import alias_pkg::*;
  typedef alias_target collision;

  forward_holder holder;
  later_item#() explicit_default_item;
  later_item#(4) explicit_forward_item;

  mutual_a root_a;
  mutual_a#() explicit_a;
  mutual_b#() explicit_b;

  container_item dynamic_items[];
  container_item queue_items[$];
  container_item associative_items[int];
  container_queue_t queue_in_dynamic[];
  container_dynamic_t dynamic_in_queue[$];

  collision alias_value;
  alias_target#() explicit_alias_value;

  forward_nested_holder nested_holder;
  forward_nested_pool#(
    forward_nested_event#(forward_nested_object)
  ) explicit_nested_pool;
  forward_nested_event#(forward_nested_object) nested_event;
  forward_nested_object nested_object;

  initial begin
    container_item queue_value;
    container_item associative_value;
    container_item nested_queue_value;
    container_item nested_dynamic_value;
    container_item#() explicit_container_value;
    container_dynamic_t dynamic_value;

    holder = new;
    holder.item = new;
    explicit_default_item = new;
    if (type(holder.item) != type(explicit_default_item)
        || $bits(holder.item.payload) != 8) begin
      $display("FAILED forward default identity");
      $finish;
    end

    explicit_forward_item = new;
    if ($bits(explicit_forward_item.payload) != 4) begin
      $display("FAILED explicit forward override");
      $finish;
    end

    root_a = new;
    root_a.b = new;
    root_a.b.a = new;
    explicit_a = new;
    explicit_b = new;
    if (type(root_a) != type(explicit_a)
        || type(root_a.b) != type(explicit_b)
        || type(root_a.b.a) != type(root_a)) begin
      $display("FAILED mutual default identity");
      $finish;
    end

    explicit_container_value = new;
    dynamic_items = new[1];
    dynamic_items[0] = explicit_container_value;
    dynamic_items[0].payload = 8'h11;

    queue_value = new;
    queue_items.push_back(queue_value);
    queue_items[0].payload = 8'h22;

    associative_value = new;
    associative_items[3] = associative_value;
    associative_items[3].payload = 8'h33;

    nested_queue_value = new;
    nested_queue_value.payload = 8'h44;
    queue_in_dynamic = new[1];
    queue_in_dynamic[0].push_back(nested_queue_value);

    nested_dynamic_value = new;
    nested_dynamic_value.payload = 8'h55;
    dynamic_value = new[1];
    dynamic_value[0] = nested_dynamic_value;
    dynamic_in_queue.push_back(dynamic_value);

    if (dynamic_items.size() != 1 || queue_items.size() != 1
        || associative_items.size() != 1
        || queue_in_dynamic.size() != 1
        || queue_in_dynamic[0].size() != 1
        || dynamic_in_queue.size() != 1
        || dynamic_in_queue[0].size() != 1
        || type(dynamic_items[0]) != type(explicit_container_value)
        || type(queue_items[0]) != type(explicit_container_value)
        || type(associative_items[3]) != type(explicit_container_value)
        || type(queue_in_dynamic[0][0]) != type(explicit_container_value)
        || type(dynamic_in_queue[0][0]) != type(explicit_container_value)
        || dynamic_items[0].payload !== 8'h11
        || queue_items[0].payload !== 8'h22
        || associative_items[3].payload !== 8'h33
        || queue_in_dynamic[0][0].payload !== 8'h44
        || dynamic_in_queue[0][0].payload !== 8'h55) begin
      $display("FAILED container preservation");
      $finish;
    end

    alias_value = new;
    explicit_alias_value = new;
    if (type(alias_value) != type(explicit_alias_value)
        || $bits(alias_value.payload) != 7) begin
      $display("FAILED exact typedef provenance");
      $finish;
    end

    nested_holder = new;
    nested_holder.pool = new;
    explicit_nested_pool = new;
    nested_event = new;
    nested_object = new;
    nested_object.marker = 1'b1;
    nested_event.payload = nested_object;
    nested_holder.pool.item = nested_event;
    nested_event = nested_holder.pool.get();
    if (type(nested_holder.pool) != type(explicit_nested_pool)
        || nested_event == null || nested_event.payload == null
        || nested_event.payload.marker !== 1'b1) begin
      $display("FAILED nested forward specialization identity");
      $finish;
    end

    $display("PASSED");
  end
endmodule
