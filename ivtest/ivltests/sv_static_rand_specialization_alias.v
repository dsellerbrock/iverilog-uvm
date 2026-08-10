// C, C#(), and explicit default actuals denote one specialization and one
// static VALUE+rand_mode cell. Nondefault actuals remain isolated.
class static_specialized_item #(int TAG = 0);
  static rand int shared;

  constraint fixed_value {
    shared == 31 + TAG;
  }
endclass

module test;
  initial begin
    static_specialized_item bare_obj;
    static_specialized_item#() empty_obj;
    static_specialized_item#(0) positional_obj;
    static_specialized_item#(.TAG(0)) named_obj;
    static_specialized_item#(1) tag1_obj;
    static_specialized_item#(.TAG(1)) named_tag1_obj;

    bare_obj = new;
    empty_obj = new;
    positional_obj = new;
    named_obj = new;
    tag1_obj = new;
    named_tag1_obj = new;

    static_specialized_item#()::shared = 7;
    static_specialized_item#(1)::shared = 19;
    if (bare_obj.randomize() !== 1)
      $fatal(1, "default specialization randomize failed");
    if (static_specialized_item#()::shared !== 31
        || empty_obj.shared !== 31
        || positional_obj.shared !== 31
        || named_obj.shared !== 31)
      $fatal(1, "default specialization values did not alias");
    if (tag1_obj.shared !== 19 || named_tag1_obj.shared !== 19)
      $fatal(1, "default randomize escaped into nondefault storage");

    if (named_tag1_obj.randomize() !== 1)
      $fatal(1, "nondefault specialization randomize failed");
    if (static_specialized_item#(1)::shared !== 32
        || tag1_obj.shared !== 32 || named_tag1_obj.shared !== 32)
      $fatal(1, "nondefault specialization values did not alias");
    if (bare_obj.shared !== 31 || positional_obj.shared !== 31)
      $fatal(1, "nondefault randomize escaped into default storage");

    bare_obj.shared.rand_mode(0);
    if (empty_obj.shared.rand_mode() !== 0
        || positional_obj.shared.rand_mode() !== 0
        || named_obj.shared.rand_mode() !== 0)
      $fatal(1, "default specialization rand_mode did not alias");
    if (tag1_obj.shared.rand_mode() !== 1)
      $fatal(1, "default rand_mode escaped into nondefault specialization");
    named_obj.shared.rand_mode(1);

    tag1_obj.shared.rand_mode(0);
    if (named_tag1_obj.shared.rand_mode() !== 0
        || bare_obj.shared.rand_mode() !== 1)
      $fatal(1, "nondefault rand_mode isolation failed");
    named_tag1_obj.shared.rand_mode(1);

    $display("PASSED");
  end
endmodule
