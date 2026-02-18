package com.github.standobyte.jojo;

import org.apache.commons.lang3.tuple.Pair;

import net.minecraftforge.common.ForgeConfigSpec;

/**
 * Minimal migration config used for staged 1.20.1 bootstrap slices.
 * Keeps only hard-gate toggles needed by JojoMod startup.
 */
public final class JojoPortConfig {
    public static final ForgeConfigSpec SPEC;
    private static final Values VALUES;

    static {
        Pair<Values, ForgeConfigSpec> pair = new ForgeConfigSpec.Builder().configure(Values::new);
        VALUES = pair.getLeft();
        SPEC = pair.getRight();
    }

    private JojoPortConfig() {}

    public static boolean enableWorldgen() {
        return VALUES.enableWorldgen.get();
    }

    public static boolean enableNonStandPowers() {
        return VALUES.enableNonStandPowers.get();
    }

    public static boolean enableOptionalCompat() {
        return VALUES.enableOptionalCompat.get();
    }

    private static final class Values {
        private final ForgeConfigSpec.BooleanValue enableWorldgen;
        private final ForgeConfigSpec.BooleanValue enableNonStandPowers;
        private final ForgeConfigSpec.BooleanValue enableOptionalCompat;

        private Values(ForgeConfigSpec.Builder builder) {
            builder.comment("Temporary migration gates for staged 1.20.1 bootstrap").push("migration");
            enableWorldgen = builder.define("enableWorldgen", false);
            enableNonStandPowers = builder.define("enableNonStandPowers", false);
            enableOptionalCompat = builder.define("enableOptionalCompat", false);
            builder.pop();
        }
    }
}
