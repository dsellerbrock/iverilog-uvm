# IEEE 1800 shallow-copy requirements

IEEE 1800-2017 and IEEE 1800-2023 §8.12 both require allocating an object of the class type being copied, without rerunning its constructor or declaration initializers. They require copying all class properties, inherited and access-controlled properties, and object handles shallowly. The static-property control follows §8.9: a static property has class-wide shared storage rather than independent per-instance state.

The probe checks scalar and derived properties, dynamic type preservation through a base handle, value-copy behavior for a queue property, shallow-copy behavior for a nested object handle, shared static state, local/protected inherited properties, and a parameterized-class property width.
