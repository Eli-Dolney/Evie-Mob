package com.ltw.mobs.client;
import com.ltw.mobs.*;
import com.mojang.blaze3d.vertex.PoseStack;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.*;
import net.minecraft.client.renderer.entity.layers.EyesLayer;
import net.minecraft.resources.ResourceLocation;

public class CompanionRenderer extends MobRenderer<Companion,CompanionModel> {
    private final ResourceLocation texture;
    public CompanionRenderer(EntityRendererProvider.Context c,boolean dragon) {
        super(c,new CompanionModel(c.bakeLayer(dragon?ClientEvents.EVIE_LAYER:ClientEvents.ELI_LAYER),dragon),dragon?1.8F:2.3F);
        texture=LtwMobs.id("textures/entity/"+(dragon?"evie":"eli")+"_v2.png");
        ResourceLocation glow=LtwMobs.id("textures/entity/"+(dragon?"evie":"eli")+"_v2_glow.png");
        addLayer(new EyesLayer<Companion,CompanionModel>(this){@Override public RenderType renderType(){return RenderType.eyes(glow);}});
    }
    @Override public ResourceLocation getTextureLocation(Companion e){return texture;}
    @Override protected void scale(Companion entity, PoseStack pose, float partialTick) {
        float size = entity.dragon ? 0.55F : 0.74F;
        pose.scale(size, size, size);
    }
}
