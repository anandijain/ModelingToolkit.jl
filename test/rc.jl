begin
    var"##iv#258" = (@variables(t))[1]
    var"##sts#259" = (collect)(@variables(resistor₊p₊i(t), source₊p₊i(t), source₊p₊v(t), resistor₊p₊v(t), capacitor₊p₊i(t), resistor₊n₊i(t), resistor₊n₊v(t), capacitor₊p₊v(t), source₊n₊i(t), ground₊g₊i(t), capacitor₊n₊i(t), capacitor₊n₊v(t), source₊n₊v(t), ground₊g₊v(t), resistor₊v(t), capacitor₊v(t)))
    var"##ps#260" = (collect)(@parameters(resistor₊R, capacitor₊C, source₊V))
    var"##eqs#261" = [0 ~ (+)(resistor₊p₊i, source₊p₊i); source₊p₊v ~ resistor₊p₊v; 0 ~ (+)(capacitor₊p₊i, resistor₊n₊i); resistor₊n₊v ~ capacitor₊p₊v; 0 ~ (+)(capacitor₊n₊i, ground₊g₊i, source₊n₊i); capacitor₊n₊v ~ source₊n₊v; source₊n₊v ~ ground₊g₊v; resistor₊v ~ (+)(resistor₊p₊v, (*)(-1, resistor₊n₊v)); 0 ~ (+)(resistor₊n₊i, resistor₊p₊i); resistor₊v ~ (*)(resistor₊R, resistor₊p₊i); capacitor₊v ~ (+)(capacitor₊p₊v, (*)(-1, capacitor₊n₊v)); 0 ~ (+)(capacitor₊n₊i, capacitor₊p₊i); (Differential(t))(capacitor₊v) ~ (*)(capacitor₊p₊i, (^)(capacitor₊C, -1)); source₊V ~ (+)(source₊p₊v, (*)(-1, source₊n₊v)); 0 ~ (+)(source₊n₊i, source₊p₊i); ground₊g₊v ~ 0]
    var"##defs#262" = (Dict)((Pair)(source₊n₊i, 1.0), (Pair)(capacitor₊C, 1.0), (Pair)(source₊V, 1.0), (Pair)(capacitor₊p₊i, 1.0), (Pair)(resistor₊R, 1.0), (Pair)(resistor₊n₊v, 1.0), (Pair)(ground₊g₊v, 1.0), (Pair)(source₊p₊v, 1.0), (Pair)(ground₊g₊i, 1.0), (Pair)(capacitor₊p₊v, 1.0), (Pair)(resistor₊p₊i, 1.0), (Pair)(source₊p₊i, 1.0), (Pair)(capacitor₊n₊v, 1.0), (Pair)(source₊n₊v, 1.0), (Pair)(resistor₊p₊v, 1.0), (Pair)(capacitor₊n₊i, 1.0), (Pair)(resistor₊n₊i, 1.0))
    (ODESystem)(var"##eqs#261", var"##iv#258", var"##sts#259", var"##ps#260"; defaults = var"##defs#262")
end