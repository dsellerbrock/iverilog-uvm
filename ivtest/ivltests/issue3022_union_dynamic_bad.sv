module issue3022_union_dynamic_bad;
  class C; endclass
  typedef int dyn_t[];
  typedef struct { dyn_t a; } nested_t;
  typedef union { int i; int data[]; } direct_t;
  typedef union { int i; dyn_t data; } alias_t;
  typedef union { int i; nested_t data; } nested_union_t;
  typedef union { int i; int data[$]; } queue_t;
  typedef union { int i; C obj; } class_t;
  typedef union { int i; string text; } string_t;
  typedef union { int i; int data[string]; } assoc_t;
  direct_t a; alias_t b; nested_union_t c; queue_t d; class_t e; string_t f; assoc_t g;
endmodule
