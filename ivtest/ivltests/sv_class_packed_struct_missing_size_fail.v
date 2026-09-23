typedef struct packed {
  bit valid;
  bit ready;
} status_t;

class model;
  status_t s;
  function int invalid_member();
    return s.size;
  endfunction
endclass

module main;
endmodule
