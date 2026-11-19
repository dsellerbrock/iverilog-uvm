interface link_if;
  logic data;
endinterface

module top;
  class Item;
    int number;
  endclass

  class Base;
    int inherited;
    int field;
    event base_event;
  endclass

  class Derived extends Base;
    int field;
    static int shared = 31;
    const local int limit = 17;
    protected rand int randomized_field;
    randc bit [2:0] choices;
    Item child;
    int matrix [3:2][-1:1];
    logic [1:0][-2:1] packed_value;
    int dynamic_values[];
    int mixed[2][];
    int lookup[string];
    int queued[$];
    virtual link_if link;
    virtual link_if links[2];
    event ready;
    static event updated;
    event slots[0:1];
    static event notifications[4:2];

    covergroup coverage;
      coverpoint field;
    endgroup
  endclass

  Derived obj;
  Derived empty_obj;
  int event_count = 0;

  initial forever begin
    @(Derived::updated);
    event_count++;
  end

  initial begin
    #1;
    obj = new;
    obj.field = 23;
    obj.child = new;
    obj.child.number = 47;
    $issue3748_check_live;
    #1;
    if (obj.field != 24 || Derived::shared != 32 || event_count != 1)
      $fatal(1, "expected only live VPI writes and one live event trigger");
    $issue3748_result;
  end
endmodule
