package com.ltw.mobs.world;
import com.ltw.mobs.*;
import com.mojang.serialization.*;
import com.mojang.serialization.codecs.RecordCodecBuilder;
import java.util.Optional;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.structure.*;

public class HabitatStructure extends Structure {
    public static final MapCodec<HabitatStructure> CODEC=RecordCodecBuilder.mapCodec(i -> i.group(settingsCodec(i),Codec.BOOL.fieldOf("sky").forGetter(s -> s.sky)).apply(i,HabitatStructure::new));
    private final boolean sky;
    public HabitatStructure(StructureSettings settings,boolean sky) { super(settings);this.sky=sky; }
    @Override public Optional<GenerationStub> findGenerationPoint(GenerationContext c) {
        if(c.random().nextDouble()>Settings.HABITAT_CHANCE.get())return Optional.empty();
        int x=c.chunkPos().getMiddleBlockX(),z=c.chunkPos().getMiddleBlockZ();
        int ground=c.chunkGenerator().getFirstOccupiedHeight(x,z,Heightmap.Types.WORLD_SURFACE_WG,c.heightAccessor(),c.randomState());
        int y=sky?Math.max(155,Math.min(230,ground+65)):c.chunkGenerator().getSeaLevel()-1;
        // Sampling at the surface preserves the expected biome filter for floating islands.
        return Optional.of(new GenerationStub(new BlockPos(x,ground,z),b -> b.addPiece(new HabitatPiece(new BlockPos(x,y,z),sky))));
    }
    @Override public StructureType<?> type(){return LtwMobs.HABITAT.get();}
}
