# §16.13.7 parser control

Run the existing §16.10 property-local-variable regression under both editions.
It uses a local property variable without a declaration initializer and assigns
it in a sequence match item. This control checks that the §16.13.7 rejection
is specific to the standard's `logic v = e;` form rather than named-property
local variables or the surrounding assertion machinery generally.
