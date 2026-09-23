module top;
  typedef struct packed { bit busy; bit wel; } status_t;

  class model;
    function int parenless();
      status_t q[$];
      q.push_back('{busy:1, wel:0});
      return q.size;
    endfunction

    function int parens();
      status_t q[$];
      q.push_back('{busy:1, wel:0});
      return q.size();
    endfunction
  endclass

  model m;
  initial begin
    m = new();
    if (m.parenless() != 1 || m.parens() != 1)
      $fatal(1, "queue size spellings disagree");
    $display("PASS queue struct size");
  end
endmodule
