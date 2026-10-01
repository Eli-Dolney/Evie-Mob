package com.ltw.mobs;

import com.ltw.mobs.world.HabitatStructure;
import com.ltw.mobs.world.HabitatPiece;
import net.minecraft.core.registries.Registries;
import net.neoforged.neoforge.common.DeferredSpawnEggItem;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.entity.*;
import net.minecraft.world.item.*;
import net.minecraft.world.level.levelgen.structure.StructureType;
import net.minecraft.world.level.levelgen.structure.pieces.StructurePieceType;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.common.Mod;
import net.neoforged.fml.config.ModConfig;
import net.neoforged.neoforge.event.entity.EntityAttributeCreationEvent;
import net.neoforged.neoforge.registries.*;

@Mod(LtwMobs.ID)
public final class LtwMobs {
    public static final String ID = "ltw_mobs";
    public static ResourceLocation id(String path) { return ResourceLocation.fromNamespaceAndPath(ID, path); }
    public static final DeferredRegister<EntityType<?>> ENTITIES = DeferredRegister.create(Registries.ENTITY_TYPE, ID);
    public static final DeferredRegister.Items ITEMS = DeferredRegister.createItems(ID);
    public static final DeferredRegister<StructureType<?>> STRUCTURES = DeferredRegister.create(Registries.STRUCTURE_TYPE, ID);
    public static final DeferredRegister<StructurePieceType> PIECES = DeferredRegister.create(Registries.STRUCTURE_PIECE, ID);
    public static final DeferredHolder<EntityType<?>, EntityType<Companion>> EVIE = ENTITIES.register("evie", () -> EntityType.Builder.<Companion>of((t,l) -> new Companion(t,l,true), MobCategory.CREATURE).sized(2.4F,3.2F).clientTrackingRange(12).build("evie"));
    public static final DeferredHolder<EntityType<?>, EntityType<Companion>> ELI = ENTITIES.register("eli", () -> EntityType.Builder.<Companion>of((t,l) -> new Companion(t,l,false), MobCategory.WATER_CREATURE).sized(3F,2.3F).clientTrackingRange(12).build("eli"));
    public static final DeferredItem<Item> EVIE_EGG = ITEMS.register("evie_spawn_egg", () -> new DeferredSpawnEggItem(EVIE,0xf4b0d7,0x8425be,new Item.Properties()));
    public static final DeferredItem<Item> ELI_EGG = ITEMS.register("eli_spawn_egg", () -> new DeferredSpawnEggItem(ELI,0x112746,0x13cfff,new Item.Properties()));
    public static final DeferredItem<Item> SKY_LOCATOR = ITEMS.register("sky_locator", () -> new LocatorItem(true,new Item.Properties().stacksTo(1)));
    public static final DeferredItem<Item> SEA_LOCATOR = ITEMS.register("sea_locator", () -> new LocatorItem(false,new Item.Properties().stacksTo(1)));
    public static final DeferredHolder<StructureType<?>, StructureType<HabitatStructure>> HABITAT = STRUCTURES.register("habitat", () -> () -> HabitatStructure.CODEC);
    public static final DeferredHolder<StructurePieceType, StructurePieceType> HABITAT_PIECE = PIECES.register("habitat", () -> HabitatPiece::new);
    public LtwMobs(IEventBus bus, ModContainer container) {
        ENTITIES.register(bus); ITEMS.register(bus); STRUCTURES.register(bus); PIECES.register(bus);
        bus.addListener(this::attributes);
        bus.addListener(RideInput::register);
        bus.addListener((net.neoforged.neoforge.event.BuildCreativeModeTabContentsEvent e) -> {
            if (e.getTabKey() == CreativeModeTabs.SPAWN_EGGS) { e.accept(EVIE_EGG); e.accept(ELI_EGG); }
            if (e.getTabKey() == CreativeModeTabs.TOOLS_AND_UTILITIES) { e.accept(SKY_LOCATOR); e.accept(SEA_LOCATOR); }
        });
        container.registerConfig(ModConfig.Type.COMMON, Settings.SPEC);
    }
    private void attributes(EntityAttributeCreationEvent event) {
        event.put(EVIE.get(), Companion.attributes().build()); event.put(ELI.get(), Companion.attributes().build());
    }
}
