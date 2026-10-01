package com.ltw.mobs.world;
import com.ltw.mobs.*;
import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.level.*;
import net.minecraft.world.level.block.*;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkGenerator;
import net.minecraft.world.level.levelgen.structure.*;
import net.minecraft.world.level.levelgen.structure.pieces.StructurePieceSerializationContext;

/** Chunk-clipped deterministic geometry; the spawn flag follows vanilla swamp-hut persistence. */
public class HabitatPiece extends StructurePiece {
    private final BlockPos center;
    private final boolean sky;
    private boolean spawned;
    public HabitatPiece(BlockPos center, boolean sky) {
        super(LtwMobs.HABITAT_PIECE.get(),0,new BoundingBox(center.getX()-32,sky?62:center.getY()-18,center.getZ()-32,center.getX()+32,center.getY()+14,center.getZ()+32));
        this.center=center;this.sky=sky;
    }
    public HabitatPiece(StructurePieceSerializationContext context,CompoundTag tag) { super(LtwMobs.HABITAT_PIECE.get(),tag);center=BlockPos.of(tag.getLong("Center"));sky=tag.getBoolean("Sky");spawned=tag.getBoolean("Spawned"); }
    @Override protected void addAdditionalSaveData(StructurePieceSerializationContext c,CompoundTag t) { t.putLong("Center",center.asLong());t.putBoolean("Sky",sky);t.putBoolean("Spawned",spawned); }
    private void put(WorldGenLevel l,BoundingBox clip,int x,int y,int z,BlockState s) {
        BlockPos p=center.offset(x,y,z);if(clip.isInside(p)&&boundingBox.isInside(p))l.setBlock(p,s,2);
    }
    private void put(WorldGenLevel l,BoundingBox clip,int x,int y,int z,Block b){put(l,clip,x,y,z,b.defaultBlockState());}
    @Override public void postProcess(WorldGenLevel l,StructureManager manager,ChunkGenerator generator,RandomSource random,BoundingBox clip,ChunkPos chunk,BlockPos pivot) {
        if(sky) skyIsland(l,clip); else lagoon(l,clip);
        BlockPos spawn=center.offset(0,sky?1:-4,0);
        if(!spawned && clip.isInside(spawn)) {
            Companion mob=(sky?LtwMobs.EVIE:LtwMobs.ELI).get().create(l.getLevel());
            if(mob!=null) { spawned=true; mob.moveTo(spawn.getX()+0.5,spawn.getY(),spawn.getZ()+0.5,180,0);mob.setHabitat(spawn);mob.finalizeSpawn(l,l.getCurrentDifficultyAt(spawn),MobSpawnType.STRUCTURE,null);l.addFreshEntityWithPassengers(mob); }
        }
    }
    private void skyIsland(WorldGenLevel l,BoundingBox clip) {
        for(int x=-22;x<=22;x++)for(int z=-22;z<=22;z++) {
            if(center.getX()+x<clip.minX()||center.getX()+x>clip.maxX()||center.getZ()+z<clip.minZ()||center.getZ()+z>clip.maxZ())continue;
            double d=Math.sqrt(x*x+z*z);double edge=20+Math.sin(x*0.7)*1.2+Math.cos(z*0.5);
            if(d>edge)continue;
            int depth=(int)(3+(edge-d)*0.65);
            for(int y=-depth;y<=0;y++)put(l,clip,x,y,z,y==0?Blocks.GRASS_BLOCK:y>=-2?Blocks.DIRT:Blocks.STONE);
            if(d>9 && Math.floorMod(x*31+z*17,23)==0)put(l,clip,x,1,z,Blocks.ALLIUM);
            if(d>12 && Math.floorMod(x*17+z*29,71)==0){put(l,clip,x,1,z,Blocks.AMETHYST_BLOCK);put(l,clip,x,2,z,Blocks.AMETHYST_CLUSTER);}
        }
        tree(l,clip,-12,-8,true);tree(l,clip,11,-11,true);tree(l,clip,12,10,true);
        for(int x=-3;x<=3;x++)for(int z=-3;z<=3;z++) if(x*x+z*z<12)put(l,clip,x,0,z,Blocks.CALCITE);
        // A three-block-wide stream reaches the edge and falls to sea level.
        for(int x=-1;x<=1;x++)for(int z=12;z<=22;z++) {put(l,clip,x,-1,z,Blocks.CALCITE);put(l,clip,x,0,z,Blocks.WATER);}
        for(int x=-1;x<=1;x++)for(int y=62-center.getY();y<=0;y++)put(l,clip,x,y,23,Blocks.WATER);
    }
    private void lagoon(WorldGenLevel l,BoundingBox clip) {
        for(int x=-31;x<=31;x++)for(int z=-31;z<=31;z++) {
            if(center.getX()+x<clip.minX()||center.getX()+x>clip.maxX()||center.getZ()+z<clip.minZ()||center.getZ()+z>clip.maxZ())continue;
            double d=Math.sqrt(x*x+z*z);if(d>31)continue;
            boolean channel=Math.abs(x)<9 && z>0;
            boolean shore=d>=23&&!channel;
            int floor=shore?-3:-(int)(8+8*Math.max(0,1-d/26));
            for(int y=-18;y<=10;y++) {
                if(y<floor)put(l,clip,x,y,z,Blocks.SANDSTONE);
                else if(y==floor)put(l,clip,x,y,z,Blocks.SAND);
                else if(shore&&y<=2)put(l,clip,x,y,z,y==2&&d>26&&d<29?Blocks.GRASS_BLOCK:Blocks.SAND);
                else if(y<=0)put(l,clip,x,y,z,Blocks.WATER);
                else put(l,clip,x,y,z,Blocks.AIR);
            }
            if(!shore && Math.floorMod(x*31+z*19,41)==0) {put(l,clip,x,floor+1,z,Blocks.BRAIN_CORAL_BLOCK);put(l,clip,x,floor+2,z,Blocks.BRAIN_CORAL);}
            if(!shore && Math.floorMod(x*13-z*23,59)==0)put(l,clip,x,floor+1,z,Blocks.SEA_LANTERN);
            if(shore&&d>26&&d<29 && Math.floorMod(x*13+z*7,13)==0)put(l,clip,x,3,z,Blocks.FERN);
        }
        tree(l,clip,-25,-9,false);tree(l,clip,23,-13,false);tree(l,clip,-16,-23,false);tree(l,clip,24,11,false);
    }
    private void tree(WorldGenLevel l,BoundingBox clip,int x,int z,boolean cherry) {
        int base=cherry?1:3;
        for(int y=base;y<base+6;y++)put(l,clip,x,y,z,cherry?Blocks.CHERRY_LOG:Blocks.JUNGLE_LOG);
        for(int dx=-3;dx<=3;dx++)for(int dz=-3;dz<=3;dz++)for(int dy=4;dy<=6;dy++)if(Math.abs(dx)+Math.abs(dz)<6)
            put(l,clip,x+dx,base+dy,z+dz,(cherry?Blocks.CHERRY_LEAVES:Blocks.JUNGLE_LEAVES).defaultBlockState().setValue(LeavesBlock.PERSISTENT,true));
    }
}
