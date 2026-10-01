package com.ltw.mobs.client;
import com.ltw.mobs.*;
import com.mojang.blaze3d.platform.InputConstants;
import net.minecraft.client.*;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.*;
import net.neoforged.neoforge.network.PacketDistributor;
import org.lwjgl.glfw.GLFW;

@EventBusSubscriber(modid=LtwMobs.ID,value=Dist.CLIENT)
public final class ClientEvents {
    public static final ModelLayerLocation EVIE_LAYER=new ModelLayerLocation(LtwMobs.id("evie"),"main");
    public static final ModelLayerLocation ELI_LAYER=new ModelLayerLocation(LtwMobs.id("eli"),"main");
    public static final KeyMapping DESCEND=new KeyMapping("key.ltw_mobs.descend",InputConstants.Type.KEYSYM,GLFW.GLFW_KEY_C,"key.categories.ltw_mobs");
    @SubscribeEvent public static void keys(RegisterKeyMappingsEvent e){e.register(DESCEND);}
    @SubscribeEvent public static void layers(EntityRenderersEvent.RegisterLayerDefinitions e){e.registerLayerDefinition(EVIE_LAYER,()->CompanionModel.create(true));e.registerLayerDefinition(ELI_LAYER,()->CompanionModel.create(false));}
    @SubscribeEvent public static void renderers(EntityRenderersEvent.RegisterRenderers e){e.registerEntityRenderer(LtwMobs.EVIE.get(),c->new CompanionRenderer(c,true));e.registerEntityRenderer(LtwMobs.ELI.get(),c->new CompanionRenderer(c,false));}
    @EventBusSubscriber(modid=LtwMobs.ID,value=Dist.CLIENT)
    public static final class Gameplay {
        @SubscribeEvent public static void tick(ClientTickEvent.Post e) {
            Minecraft mc=Minecraft.getInstance();
            if(mc.player!=null&&mc.player.getVehicle() instanceof Companion) {
                boolean active=mc.screen==null;
                float f=active?(mc.options.keyUp.isDown()?1:0)-(mc.options.keyDown.isDown()?1:0):0;
                float s=active?(mc.options.keyLeft.isDown()?1:0)-(mc.options.keyRight.isDown()?1:0):0;
                PacketDistributor.sendToServer(new RideInput(f,s,mc.player.getYRot(),active&&mc.options.keyJump.isDown(),active&&DESCEND.isDown(),active&&mc.options.keySprint.isDown()));
            }
        }
    }
}
