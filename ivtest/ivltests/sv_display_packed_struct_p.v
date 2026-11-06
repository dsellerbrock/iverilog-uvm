module sv_display_packed_struct_p;
  typedef struct packed { logic [3:0] a; bit [3:0] b; } inner_t;
  typedef struct packed { inner_t inner; logic [3:0] c; } outer_t;
  typedef struct packed { logic signed [3:0] value; } signed_t;

  inner_t inner = '{a:4'h3, b:4'h5};
  outer_t outer = '{inner: inner, c:4'h9};
  signed_t signed_value = '{value:-1};

  initial begin
    $display("%p", inner);
    $display("%p", outer);
    $display("%p", signed_value);
  end
endmodule
