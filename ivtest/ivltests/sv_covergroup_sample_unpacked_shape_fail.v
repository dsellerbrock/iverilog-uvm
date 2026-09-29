// A fixed two-word covergroup sample formal cannot accept a three-word array.
module top;
  typedef struct packed { logic Z, L, M, C; } flags_t;
  flags_t wrong_size[2:0];
  covergroup cg with function sample(flags_t flags[1:0]);
    cp: coverpoint flags[0].C { bins zero = {0}; }
  endgroup
  cg cov;
  initial begin
    cov = new;
    cov.sample(wrong_size);
  end
endmodule
