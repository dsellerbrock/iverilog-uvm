// IEEE 1800-2017/2023 7.3.2, 11.9, 38.36.1.
`timescale 1ns/1ns
module top;
  class Item;
    int data;
  endclass

  typedef struct { logic bits; real number; } payload_t;
  typedef struct { bit [2:0] id; } key_t;
  typedef union tagged { void Empty; logic Data; } element_t;
  typedef element_t map_t[key_t];
  typedef logic dynamic_t[];
  typedef real queue_t[$];
  typedef union tagged {
    void Empty;
    void Other;
    logic Data;
    payload_t Nested;
    map_t Map;
    dynamic_t Dynamic;
    queue_t Queue;
    Item Ref;
  } value_t;

  value_t value;
  key_t first_key, second_key, third_key;
  element_t x, z;
  map_t a, b;
  dynamic_t bits;
  queue_t numbers;
  Item item, other;

  initial begin
    first_key.id = 1;
    second_key.id = 2;
    third_key.id = 3;
    x = tagged Data (1'bx);
    z = tagged Data (1'bz);
    a[first_key] = x;
    a[second_key] = z;
    b[second_key] = z;
    b[first_key] = x;
    bits = new[2];
    numbers.push_back(0.0);
    item = new;
    other = new;

    value = tagged Empty;
    $watch_tagged_union;
    #1 value = tagged Empty;
    #1 value = tagged Other;
    #1 value = tagged Data (1'bx);
    #1 value = tagged Data (1'bx);
    #1 value = tagged Data (1'bz);
    #1 value = tagged Data (1'bz);
    #1 value = tagged Nested '{1'bx, 0.0};
    #1 value = tagged Nested '{1'bx, 0.0};
    #1 value.Nested.bits = 1'bx;
    #1 value.Nested.bits = 1'bz;
    #1 value.Nested.number = -0.0;
    #1 value.Nested.number = -0.0;

    #1 value = tagged Map (a);
    #1 value = tagged Map (b);
    #1 value.Map[first_key] = z;
    #1 value.Map[first_key] = z;
    b.delete(second_key);
    b[first_key] = z;
    b[third_key] = z;
    #1 value = tagged Map (b);

    #1 value = tagged Dynamic (bits);
    #1 value.Dynamic[1] = 1'bx;
    #1 value.Dynamic[1] = 1'bz;
    #1 value = tagged Queue (numbers);
    #1 value.Queue[0] = -0.0;
    #1 value.Queue[0] = -0.0;

    #1 value = tagged Ref (item);
    #1 value = tagged Ref (item);
    #1 value.Ref.data = 1;
    #1 value = tagged Ref (other);

    #1 value = tagged Nested '{1'b0, 0.0};
    #1 $unwatch_tagged_union;
    #1 value.Nested.bits = 1'b1;
  end
endmodule
