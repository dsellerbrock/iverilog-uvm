// A bad inner packed index must not carry into the neighboring outer element.
typedef enum logic [3:0] { A=4'h1, B=4'h2, C=4'h3, D=4'h4 } flag_t;
class holder;
  flag_t [1:0][1:0] flags;
  task check();
    flag_t got;
    int outer_idx, inner_idx;
    flags = 16'h1234;
    got = flags[0][2];
    if (got !== 4'hx) $fatal(1, "bad inner read aliased %h", got);
    flags[0][2] = D;
    if (flags !== 16'h1234) $fatal(1, "bad inner write changed %h", flags);
    outer_idx = 0;
    inner_idx = 2;
    got = flags[outer_idx][inner_idx];
    if (got !== 4'hx) $fatal(1, "variable bad inner read aliased %h", got);
    flags[outer_idx][inner_idx] = D;
    if (flags !== 16'h1234) $fatal(1, "variable bad inner write changed %h", flags);
    inner_idx = 0;
    got = flags[outer_idx][inner_idx++];
    if (got !== D || inner_idx != 1)
      $fatal(1, "index side effect duplicated: value %h, index %0d", got, inner_idx);
    flags[outer_idx][inner_idx++] = D;
    if (flags !== 16'h1244 || inner_idx != 2)
      $fatal(1, "write index side effect duplicated: value %h, index %0d", flags, inner_idx);
  endtask
endclass
module top;
  holder h;
  initial begin h=new; h.check(); $display("PASSED"); end
endmodule
