// IEEE 1800-2017 21.2.1.7 / IEEE 1800-2023 21.2.1.6
typedef enum logic [1:0] { IDLE = 0, BUSY = 2 } state_t;
typedef struct packed {
  logic signed [3:0] delta;
  state_t state;
  logic flag;
} leaf_t;
typedef struct packed { logic [6:0] raw; } source_t;
class handle_t;
endclass
typedef struct {
  leaf_t q[$];
  leaf_t d[];
  leaf_t nested[$][$];
  leaf_t mixed[][$];
  leaf_t entries[int];
  leaf_t tags[string];
  handle_t handles[];
} holder_t;
module issue3784;
  holder_t holder;
  leaf_t item, other;
  leaf_t inner_q[$];
  source_t source_q[$];
  leaf_t inner_d[];
  leaf_t nested[$][$];
  leaf_t mixed[][$];
  leaf_t deep[$][][$];
  initial begin
    item = {-4'sd2, BUSY, 1'b1};
    other = {4'sd3, IDLE, 1'bz};
    holder.q.push_back(item);
    source_q.push_back(item);
    inner_q = source_q;
    inner_q.push_back(other);
    inner_d = new[1];
    inner_d[0] = other;
    holder.d = inner_d;
    nested.push_back(inner_q);
    holder.nested = nested;
    mixed = new[2];
    mixed[1] = inner_q;
    holder.mixed = mixed;
    deep.push_back(mixed);
    holder.entries[19] = other;
    holder.entries[-3] = item;
    holder.tags[""] = other;
    holder.tags["q\"x"] = item;
    holder.handles = new[1];
    $display("SOURCE=%p", source_q);
    $display("HOLDER=%p", holder);
    $display("NESTED=%p", nested);
    $display("MIXED=%p", mixed);
    $display("DEEP=%p", deep);
  end
endmodule
