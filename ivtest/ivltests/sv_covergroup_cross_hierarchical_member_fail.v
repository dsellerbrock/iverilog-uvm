interface coverage_if;
  typedef struct packed { logic valid; logic clear; } status_t;
  status_t producer, consumer;
  covergroup cg;
    invalid: cross producer.valid, consumer.clear;
  endgroup
endinterface
