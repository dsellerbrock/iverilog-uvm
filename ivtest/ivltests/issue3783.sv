module issue3783;
  typedef struct packed {
    logic [1:0] n;
    logic valid;
  } elem_t;

  elem_t q[$];
  elem_t d[];
  elem_t a[int];
  elem_t sample;

  initial begin
    $display("empty %p %p %p", q, d, a);

    sample = 3'b111;
    q.push_back(sample);
    $display("queue %p", q);

    d = new[2];
    d[0] = sample;
    d[1] = 3'b10x;
    $display("dynamic %p", d);

    a[2] = d[1];
    a[-3] = sample;
    $display("assoc %p", a);
  end
endmodule
