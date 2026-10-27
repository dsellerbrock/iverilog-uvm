module sv_force_var_select_fail;
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
  wire [15:0] bus;
  assign bus = 16'h1234;

  initial begin
    force q[0] = 1'b1;                 // E1
    force q[3:2] = 2'b11;              // E1
    force q[1+:2] = 2'b11;             // E1
    force q[3-:2] = 2'b11;             // E1
    force p[0] = 8'hff;                // E1
    force p[0][1] = 1'b1;              // E1
    force i[0] = 1'b1;                 // E1
    force mem[0][3:0] = 4'hf;          // E1
    force {q[1], q[0]} = 2'b10;        // E2
    force s.f[1] = 1'b1;               // E1
    force u.f[1] = 1'b1;               // E1
    release u.f[1];                    // E1
    release q[0];                      // E1
    release {q[1], q[0]};              // E2
    force v[1].f[0] = 1'b1;            // E1
    force o.arr[1].f[0] = 1'b1;        // E1
    force u2.parr[1].f[0] = 1'b1;      // E1
    release v[1].f[0];                 // E1
    force w[0][1].f[0] = 1'b1;         // E1
    force u.words[0][1] = 1'b1;        // E1
    force dyn[0][0] = 1'b1;             // E1
    release dyn[0][0];                  // E1
    force queue[0][1:0] = 2'b11;        // E1

    force q = 4'h5;
    release q;
    force {q, r} = 8'ha5;
    release {q, r};
    force mem[1] = 16'h1234;
    release mem[1];
    force bus[7:4] = 4'h3;
    release bus[7:4];
  end
endmodule
