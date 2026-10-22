# Open/closed dedupe

The existing #844 issue already includes an open-and-closed search of “function in constraint,” “constraint function call,” “18.5.12,” “function implicit ordering,” and related function-result ordering searches. It found only closed #680 (non-rand function arguments in inline constraints) and #494 (queue-size leaves), neither of which covers this mechanism. This probe is a depth check for #844; any observed failures will be reported there, with no new issue unless the lead identifies an unrelated gap.
