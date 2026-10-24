module sv_assign_var_select_fail;
  logic [3:0] q, r;
  logic [1:0][7:0] p;
  int i;
  logic [15:0] mem [0:1];
  typedef struct packed { logic [3:0] f; logic g; } s_t;
  s_t s;
  typedef struct { logic [3:0] f; logic [7:0] words[2]; } u_t;
  u_t u;
  typedef struct packed { s_t [1:0] arr; } o_t;
  typedef struct { s_t [1:0] parr; } u2_t;
  s_t [1:0] v;
  o_t o;
  u2_t u2;
  s_t [1:0] w[2];
  logic [3:0] dyn[];
  logic [3:0] queue[$];

  initial begin
    assign q[0] = 1'b1;                 // E1
    assign q[3:2] = 2'b11;              // E1
    assign q[1+:2] = 2'b11;             // E1
    assign q[3-:2] = 2'b11;             // E1
    assign p[0] = 8'hff;                // E1
    assign p[0][1] = 1'b1;              // E1
    assign i[0] = 1'b1;                 // E1
    assign mem[0][3:0] = 4'hf;          // E1
    assign {q[1], q[0]} = 2'b10;        // E2
    assign s.f[1] = 1'b1;               // E1
    assign u.f[1] = 1'b1;               // E1
    deassign u.f[1];                     // E1
    deassign q[0];                      // E1
    deassign {q[1], q[0]};              // E2
    assign v[1].f[0] = 1'b1;            // E1
    assign o.arr[1].f[0] = 1'b1;        // E1
    assign u2.parr[1].f[0] = 1'b1;      // E1
    assign w[0][1].f[0] = 1'b1;         // E1
    deassign v[1].f[0];                 // E1
    assign u.words[0][1] = 1'b1;        // E1
    assign dyn[0][0] = 1'b1;            // E1
    assign queue[0][1:0] = 2'b11;       // E1
    deassign dyn[0][0];                 // E1

    assign q = 4'h5;
    deassign q;
    assign {q, r} = 8'ha5;
    deassign {q, r};
    {q[1], q[0]} = 2'b10;
  end
endmodule
