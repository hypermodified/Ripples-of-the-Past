package com.github.standobyte.jojo;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;


import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.ModLoadingContext;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.config.ModConfig;
import net.minecraftforge.fml.event.lifecycle.FMLCommonSetupEvent;
import net.minecraftforge.fml.event.lifecycle.InterModEnqueueEvent;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(JojoMod.MOD_ID)
public class JojoMod {
    public static final String MOD_ID = "jojo";
    public static final Logger LOGGER = LogManager.getLogger();
    
    @Deprecated
    // Use the field in ModItems; kept as Object for cross-version bootstrap compatibility.
    public static final Object MAIN_TAB = resolveMainTab();
    
    public static Logger getLogger() {
        return LOGGER;
    }
    
    public JojoMod() {
        ModLoadingContext.get().registerConfig(ModConfig.Type.COMMON, JojoPortConfig.SPEC);
        boolean enableWorldgen = JojoPortConfig.enableWorldgen();
        boolean enableNonStandPowers = JojoPortConfig.enableNonStandPowers();
        boolean enableOptionalCompat = JojoPortConfig.enableOptionalCompat();
        LOGGER.info("RotP feature gates: worldgen={}, nonStandPowers={}, optionalCompat={}",
                enableWorldgen, enableNonStandPowers, enableOptionalCompat);
        
        final IEventBus modEventBus = FMLJavaModLoadingContext.get().getModEventBus();
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModBlocks", "BLOCKS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModItems", "ITEMS");
        
        invokeStaticWithArgsIfPresent("com.github.standobyte.jojo.init.power.JojoCustomRegistries", "initCustomRegistries", new Class<?>[] { IEventBus.class, boolean.class }, new Object[] { modEventBus, enableNonStandPowers });
        registerVanillaDeferredRegisters(modEventBus);

        modEventBus.addListener(this::preInit);
        modEventBus.addListener(this::interMod);
        invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.init.ModTags", "initTags");
    }

    private void registerVanillaDeferredRegisters(IEventBus modEventBus) {
        boolean enableWorldgen = JojoPortConfig.enableWorldgen();

        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModEntityAttributes", "ATTRIBUTES");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModContainers", "CONTAINERS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModDataSerializers", "DATA_SERIALIZERS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModStatusEffects", "EFFECTS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModEnchantments", "ENCHANTMENTS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModEntityTypes", "ENTITIES");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModFluids", "FLUIDS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModLootModifierSerializers", "LOOT_MODIFIER_SERIALIZERS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModPaintings", "PAINTINGS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModParticles", "PARTICLES");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModPotions", "POTIONS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModRecipeSerializers", "SERIALIZERS");
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModSounds", "SOUNDS");
        if (enableWorldgen) {
            registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModStructures", "STRUCTURES");
            registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModStructures", "FEATURES");
        }
        registerDeferredRegister(modEventBus, "com.github.standobyte.jojo.init.ModTileEntities", "TILE_ENTITIES");
    }
    
    
    

    private static void invokeStaticNoArgsIfPresent(String className, String methodName) {
        try {
            Class<?> clazz = Class.forName(className);
            clazz.getMethod(methodName).invoke(null);
        }
        catch (ClassNotFoundException e) {
            LOGGER.debug("Optional class not present in current port scope: {}", className);
        }
        catch (ReflectiveOperationException e) {
            LOGGER.warn("Failed to invoke {}#{} during staged port init", className, methodName, e);
        }
    }

    private static void invokeCommonSetupOnRegistryEntries(Iterable<?> entries, String registryName) {
        for (Object entry : entries) {
            try {
                entry.getClass().getMethod("onCommonSetup").invoke(entry);
            }
            catch (ReflectiveOperationException e) {
                LOGGER.warn("Failed to call onCommonSetup for {} entry {}", registryName, entry.getClass().getName(), e);
            }
        }
    }


    private static Object resolveMainTab() {
        try {
            Class<?> modItems = Class.forName("com.github.standobyte.jojo.init.ModItems");
            Field mainTab = modItems.getField("MAIN_TAB");
            return mainTab.get(null);
        }
        catch (ReflectiveOperationException e) {
            LOGGER.warn("Failed to resolve ModItems.MAIN_TAB during staged port bootstrap", e);
            return null;
        }
    }

    private static void registerDeferredRegister(IEventBus modEventBus, String className, String fieldName) {
        try {
            Class<?> clazz = Class.forName(className);
            Field field = clazz.getField(fieldName);
            Object deferredRegister = field.get(null);
            Method registerMethod = deferredRegister.getClass().getMethod("register", IEventBus.class);
            registerMethod.invoke(deferredRegister, modEventBus);
        }
        catch (ClassNotFoundException e) {
            LOGGER.debug("Optional class not present in current port scope: {}", className);
        }
        catch (ReflectiveOperationException e) {
            LOGGER.warn("Failed to register {}.{} during staged port init", className, fieldName, e);
        }
    }

    private static void invokeStaticWithArgsIfPresent(String className, String methodName, Class<?>[] argTypes, Object[] argValues) {
        try {
            Class<?> clazz = Class.forName(className);
            clazz.getMethod(methodName, argTypes).invoke(null, argValues);
        }
        catch (ClassNotFoundException e) {
            LOGGER.debug("Optional class not present in current port scope: {}", className);
        }
        catch (ReflectiveOperationException e) {
            LOGGER.warn("Failed to invoke {}#{} during staged port init", className, methodName, e);
        }
    }

    private static void invokeCommonSetupOnRegistryEntriesFromHolder(String holderClassName, String holderFieldName, String registryName) {
        try {
            Class<?> holderClass = Class.forName(holderClassName);
            Field holderField = holderClass.getField(holderFieldName);
            Object registryHolder = holderField.get(null);
            Object registry = registryHolder.getClass().getMethod("getRegistry").invoke(registryHolder);
            if (registry instanceof Iterable<?>) {
                invokeCommonSetupOnRegistryEntries((Iterable<?>) registry, registryName);
            }
        }
        catch (ClassNotFoundException e) {
            LOGGER.debug("Optional class not present in current port scope: {}", holderClassName);
        }
        catch (ReflectiveOperationException e) {
            LOGGER.warn("Failed to invoke onCommonSetup for holder {}.{}", holderClassName, holderFieldName, e);
        }
    }

    private static void invokeStaticWithSingleArgIfPresent(String className, String methodName, Class<?> argType, Object argValue) {
        try {
            Class<?> clazz = Class.forName(className);
            clazz.getMethod(methodName, argType).invoke(null, argValue);
        }
        catch (ClassNotFoundException e) {
            LOGGER.debug("Optional class not present in current port scope: {}", className);
        }
        catch (ReflectiveOperationException e) {
            LOGGER.warn("Failed to invoke {}#{} during staged port init", className, methodName, e);
        }
    }

    private static void setAttackDamageSyncable(boolean syncable) {
        try {
            Class<?> attributesClass = Class.forName("net.minecraft.entity.ai.attributes.Attributes");
            Object attackDamage = attributesClass.getField("ATTACK_DAMAGE").get(null);
            attackDamage.getClass().getMethod("setSyncable", boolean.class).invoke(attackDamage, syncable);
            return;
        }
        catch (ReflectiveOperationException ignored) {}

        try {
            Class<?> attributesClass = Class.forName("net.minecraft.world.entity.ai.attributes.Attributes");
            Object attackDamage = attributesClass.getField("ATTACK_DAMAGE").get(null);
            attackDamage.getClass().getMethod("setSyncable", boolean.class).invoke(attackDamage, syncable);
        }
        catch (ReflectiveOperationException e) {
            LOGGER.warn("Failed to set ATTACK_DAMAGE syncable during staged port init", e);
        }
    }


    private void preInit(FMLCommonSetupEvent event) {
        event.enqueueWork(() -> {
            boolean enableWorldgen = JojoPortConfig.enableWorldgen();
            boolean enableNonStandPowers = JojoPortConfig.enableNonStandPowers();
            LOGGER.info("RotP preInit feature gates: worldgen={}, nonStandPowers={}", enableWorldgen, enableNonStandPowers);

            if (enableWorldgen) {
                invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.world.dimension.ModDimensions", "init");
            }
            invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.util.ForgeBusEventSubscriber", "registerCapabilities");
            
            invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.command.argument.StandArgument", "commonSetupRegister");
            if (enableNonStandPowers) {
                invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.command.argument.NonStandTypeArgument", "commonSetupRegister");
            }
            invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.command.argument.ActionArgument", "commonSetupRegister");

            invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.advancements.ModCriteriaTriggers$CriteriaTriggerSupplier", "registerAll");
            
            invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.network.PacketManager", "init");
            
            invokeStaticWithSingleArgIfPresent("com.github.standobyte.jojo.command.ConfigPackCommand", "initConfigs", net.minecraftforge.eventbus.api.IEventBus.class, MinecraftForge.EVENT_BUS);
            
            // things to do after registry events
            invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.init.ModStatusEffects", "afterEffectsRegister");
            invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.init.ModPotions", "registerRecipes");
            
            invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.action.Action", "initShiftVariations");
            if (enableNonStandPowers) {
                invokeCommonSetupOnRegistryEntriesFromHolder("com.github.standobyte.jojo.init.power.JojoCustomRegistries", "HAMON_SKILLS", "hamon");
                invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.power.impl.nonstand.type.hamon.skill.BaseHamonSkillTree", "initTrees");
            }
            invokeCommonSetupOnRegistryEntriesFromHolder("com.github.standobyte.jojo.init.power.JojoCustomRegistries", "ACTIONS", "action");
            invokeCommonSetupOnRegistryEntriesFromHolder("com.github.standobyte.jojo.init.power.JojoCustomRegistries", "STANDS", "stand");
            
            invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.init.ModGamerules", "load");
        });
        
        setAttackDamageSyncable(true);
    }
    
    private void interMod(InterModEnqueueEvent event) {
        event.enqueueWork(() -> {
            if (JojoPortConfig.enableOptionalCompat()) {
                invokeStaticNoArgsIfPresent("com.github.standobyte.jojo.modcompat.OptionalDependencyHelper", "init");
            }
        });
    }
}
