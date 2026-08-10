module sv_ustruct_member_defaults_shape_fail;
  typedef struct {
    integer value = 7;
  } item_t;

  item_t fixed_items[2];
  item_t dynamic_items[];
  item_t queue_items[$];
  item_t associative_items[int];

  typedef item_t item_array_t[2];
  item_array_t typedef_items;

  typedef struct {
    item_array_t nested_items;
  } wrapper_t;
  wrapper_t nested_array_member;

  typedef byte byte_array_t[4];
  typedef struct {
    byte direct_data[4] = '{4{1}};
    byte_array_t typedef_data = '{4{2}};
  } member_array_defaults_t;
  member_array_defaults_t member_array_value;

  const item_t const_variable;

  class const_holder;
    const item_t const_property;
    const static item_t static_const_property;
  endclass
endmodule
