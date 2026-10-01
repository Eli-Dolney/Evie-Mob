package com.ltw.mobs;
import net.neoforged.neoforge.common.ModConfigSpec;
public final class Settings {
    public static final ModConfigSpec SPEC;
    public static final ModConfigSpec.DoubleValue FLIGHT_SPEED, SWIM_SPEED, HABITAT_CHANCE;
    static {
        var b = new ModConfigSpec.Builder();
        FLIGHT_SPEED=b.comment("Evie cruise speed in blocks per tick; sprint multiplies by 1.6.").defineInRange("flightSpeed",0.65,0.1,1.5);
        SWIM_SPEED=b.comment("ELi cruise speed in blocks per tick; sprint multiplies by 1.6.").defineInRange("swimSpeed",0.8,0.1,1.5);
        HABITAT_CHANCE=b.comment("Fraction of candidate habitats enabled in newly generated terrain. Restart after changing. Structure spacing is also data-pack configurable.").defineInRange("habitatChance",1.0,0.0,1.0);
        SPEC=b.build();
    }
}
