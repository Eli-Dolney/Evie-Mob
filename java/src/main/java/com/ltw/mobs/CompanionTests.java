package com.ltw.mobs;
import net.minecraft.core.BlockPos;
import net.minecraft.gametest.framework.*;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.*;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.gametest.*;

@GameTestHolder(LtwMobs.ID)
@PrefixGameTestTemplate(false)
public class CompanionTests {
    private static Player owner(GameTestHelper h) {return h.makeMockPlayer(GameType.SURVIVAL);}
    private static void feed(Companion c,Player p,int n) {p.setItemInHand(InteractionHand.MAIN_HAND,new ItemStack(c.dragon?Items.GLOW_BERRIES:Items.TROPICAL_FISH,n));for(int i=0;i<n;i++)c.mobInteract(p,InteractionHand.MAIN_HAND);}
    private static void saddle(Companion c,Player p){p.setItemInHand(InteractionHand.MAIN_HAND,new ItemStack(Items.SADDLE));c.mobInteract(p,InteractionHand.MAIN_HAND);}
    @GameTest(template="empty") public static void tamingAndPersistence(GameTestHelper h) {
        for(boolean dragon:new boolean[]{true,false}) {
            Companion c=(dragon?LtwMobs.EVIE:LtwMobs.ELI).get().create(h.getLevel());Player p=owner(h);
            feed(c,p,4);h.assertFalse(c.isTame(),"Four treats must not tame");
            CompoundTag trust=new CompoundTag();c.addAdditionalSaveData(trust);
            Companion loaded=(dragon?LtwMobs.EVIE:LtwMobs.ELI).get().create(h.getLevel());loaded.readAdditionalSaveData(trust);
            h.assertTrue(loaded.trust()==4,"Trust survives reload");feed(loaded,p,1);h.assertTrue(loaded.isOwnedBy(p),"Fifth treat establishes ownership");
            saddle(loaded,p);h.assertTrue(loaded.saddled(),"Saddle equips");h.assertTrue(p.getMainHandItem().isEmpty(),"Saddle consumed");
            CompoundTag data=new CompoundTag();loaded.addAdditionalSaveData(data);c.readAdditionalSaveData(data);
            h.assertTrue(c.isOwnedBy(p)&&c.saddled()&&c.isOrderedToSit(),"Owner, saddle and stay survive reload");
        }
        h.succeed();
    }
    @GameTest(template="empty") public static void ownerOnlyRiding(GameTestHelper h) {
        Companion c=h.spawn(LtwMobs.EVIE.get(),new BlockPos(4,2,4));Player p=owner(h),stranger=owner(h);feed(c,p,5);saddle(c,p);
        stranger.setItemInHand(InteractionHand.MAIN_HAND,ItemStack.EMPTY);c.mobInteract(stranger,InteractionHand.MAIN_HAND);h.assertFalse(c.isVehicle(),"Stranger cannot ride");
        p.setItemInHand(InteractionHand.MAIN_HAND,ItemStack.EMPTY);c.mobInteract(p,InteractionHand.MAIN_HAND);h.assertTrue(c.getRider()==p,"Owner mounts");
        h.assertTrue(c.getControllingPassenger()==null,"Vanilla vehicle position packets cannot control this mount");
        p.stopRiding();h.assertTrue(p.hasEffect(net.minecraft.world.effect.MobEffects.SLOW_FALLING),"Dragon dismount protects rider");h.succeed();
    }
    @GameTest(template="empty",timeoutTicks=640) public static void recovery(GameTestHelper h) {
        Companion c=h.spawn(LtwMobs.EVIE.get(),new BlockPos(4,2,4));feed(c,owner(h),5);
        c.hurt(h.getLevel().damageSources().genericKill(),1000);h.assertTrue(c.isAlive()&&c.recovery()==600,"Lethal hit enters recovery");
        c.hurt(h.getLevel().damageSources().inWall(),1000);h.assertTrue(c.isAlive()&&c.getHealth()==1,"Recovery prevents environmental damage");
        CompoundTag data=new CompoundTag();c.addAdditionalSaveData(data);Companion copy=LtwMobs.EVIE.get().create(h.getLevel());copy.readAdditionalSaveData(data);h.assertTrue(copy.recovery()==600,"Recovery survives save/load");
        h.runAtTickTime(605,()->{h.assertTrue(c.isAlive()&&c.recovery()==0&&c.getHealth()==c.getMaxHealth(),"Heals after 30 seconds");h.succeed();});
    }
    @GameTest(template="empty",timeoutTicks=80) public static void serverFlightAndTimeout(GameTestHelper h) {
        Companion c=h.spawn(LtwMobs.EVIE.get(),new BlockPos(4,3,4));Player p=owner(h);feed(c,p,5);saddle(c,p);p.setItemInHand(InteractionHand.MAIN_HAND,ItemStack.EMPTY);c.mobInteract(p,InteractionHand.MAIN_HAND);
        double start=c.getY();c.acceptInput(new RideInput(0,0,0,true,false,false));
        h.runAtTickTime(8,()->h.assertTrue(c.getY()>start+0.5,"Server flight ascends from input"));
        h.runAtTickTime(45,()->{h.assertTrue(Math.abs(c.getDeltaMovement().y)<0.01,"Expired input stops ascent");c.acceptInput(new RideInput(Float.NaN,0,0,true,false,true));h.assertTrue(Double.isFinite(c.getY()),"Non-finite input rejected");h.succeed();});
    }
    @GameTest(template="empty",timeoutTicks=60) public static void underwaterRiding(GameTestHelper h) {
        for(int x=0;x<12;x++)for(int z=0;z<12;z++)for(int y=1;y<8;y++)h.setBlock(new BlockPos(x,y,z),Blocks.WATER);
        Companion c=h.spawn(LtwMobs.ELI.get(),new BlockPos(5,3,5));Player p=owner(h);feed(c,p,5);saddle(c,p);p.setItemInHand(InteractionHand.MAIN_HAND,ItemStack.EMPTY);c.mobInteract(p,InteractionHand.MAIN_HAND);
        h.runAtTickTime(5,()->{h.assertTrue(p.hasEffect(net.minecraft.world.effect.MobEffects.WATER_BREATHING),"Mounted rider breathes");h.assertTrue(p.hasEffect(net.minecraft.world.effect.MobEffects.NIGHT_VISION),"Mounted rider sees underwater");p.stopRiding();h.assertTrue(p.getEffect(net.minecraft.world.effect.MobEffects.WATER_BREATHING).getDuration()>=1199,"Dismount grants 60 seconds");h.succeed();});
    }
    @GameTest(template="empty") public static void separateOwners(GameTestHelper h) {
        Companion a=LtwMobs.EVIE.get().create(h.getLevel()),b=LtwMobs.ELI.get().create(h.getLevel());Player first=owner(h),second=owner(h);feed(a,first,5);feed(b,second,5);
        h.assertTrue(a.isOwnedBy(first)&&b.isOwnedBy(second)&&!a.isOwnedBy(second)&&!b.isOwnedBy(first),"Companions keep independent owners");h.succeed();
    }
    @GameTest(template="empty",timeoutTicks=200) public static void skyHabitatAndReload(GameTestHelper h) { habitat(h,true); }
    @GameTest(template="empty",timeoutTicks=200) public static void lagoonHabitatAndReload(GameTestHelper h) { habitat(h,false); }
    private static void habitat(GameTestHelper h,boolean sky) {
        var level=h.getLevel();
        BlockPos anchor=h.absolutePos(new BlockPos(sky?160:320,0,160));
        BlockPos center=new BlockPos(anchor.getX(),sky?160:62,anchor.getZ());
        var piece=new com.ltw.mobs.world.HabitatPiece(center,sky);
        var box=piece.getBoundingBox();
        for(int x=box.minX()>>4;x<=box.maxX()>>4;x++)for(int z=box.minZ()>>4;z<=box.maxZ()>>4;z++)level.getChunk(x,z);
        var chunk=new net.minecraft.world.level.ChunkPos(center);
        piece.postProcess(level,level.structureManager(),level.getChunkSource().getGenerator(),level.random,box,chunk,center);
        var type=sky?LtwMobs.EVIE.get():LtwMobs.ELI.get();
        var bounds=net.minecraft.world.phys.AABB.of(box);
        h.assertTrue(level.getEntities(type,bounds,e->true).size()==1,"Habitat creates exactly one companion");
        if(sky) {
            h.assertTrue(level.getBlockState(center).is(Blocks.CALCITE),"Landing pad exists");
            h.assertTrue(level.getFluidState(center.offset(0,-20,23)).is(net.minecraft.tags.FluidTags.WATER),"Climbable waterfall exists");
        } else {
            h.assertTrue(level.getFluidState(center.offset(0,-8,0)).is(net.minecraft.tags.FluidTags.WATER),"Lagoon is deep enough");
            h.assertTrue(level.getFluidState(center.offset(0,-3,29)).is(net.minecraft.tags.FluidTags.WATER),"Ocean entrance is open");
            h.assertTrue(level.getBlockState(center.offset(28,2,0)).is(Blocks.GRASS_BLOCK),"Tropical shore exists");
        }
        var context=net.minecraft.world.level.levelgen.structure.pieces.StructurePieceSerializationContext.fromLevel(level);
        var restored=new com.ltw.mobs.world.HabitatPiece(context,piece.createTag(context));
        restored.postProcess(level,level.structureManager(),level.getChunkSource().getGenerator(),level.random,box,chunk,center);
        h.assertTrue(level.getEntities(type,bounds,e->true).size()==1,"Reloading structure data must not duplicate companion");
        h.succeed();
    }
}
