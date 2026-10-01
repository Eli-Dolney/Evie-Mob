package com.ltw.mobs;
import java.util.List;
import net.minecraft.core.BlockPos;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.GlobalPos;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.tags.TagKey;
import net.minecraft.world.*;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.*;
import net.minecraft.world.item.component.LodestoneTracker;
import net.minecraft.world.level.Level;

public class LocatorItem extends Item {
    private final boolean sky;
    public LocatorItem(boolean sky,Properties p){super(p);this.sky=sky;}
    @Override public InteractionResultHolder<ItemStack> use(Level level,Player p,InteractionHand hand) {
        ItemStack stack=p.getItemInHand(hand);
        if(level instanceof ServerLevel server) {
            p.getCooldowns().addCooldown(this,100);
            if(level.dimension()!=Level.OVERWORLD) {p.displayClientMessage(Component.translatable("message.ltw_mobs.overworld"),true);return InteractionResultHolder.fail(stack);}
            BlockPos pos=server.findNearestMapStructure(TagKey.create(Registries.STRUCTURE,LtwMobs.id(sky?"sky_habitats":"sea_habitats")),p.blockPosition(),10,false);
            if(pos==null)p.displayClientMessage(Component.translatable("message.ltw_mobs.not_found"),false);
            else {
                stack.set(DataComponents.LODESTONE_TRACKER,new LodestoneTracker(java.util.Optional.of(GlobalPos.of(level.dimension(),pos)),false));
                p.displayClientMessage(Component.translatable("message.ltw_mobs.located",Component.translatable(sky?"habitat.ltw_mobs.sky":"habitat.ltw_mobs.sea"),pos.getX(),pos.getZ()),false);
            }
        }
        return InteractionResultHolder.sidedSuccess(stack,level.isClientSide);
    }
    @Override public void appendHoverText(ItemStack stack,TooltipContext context,List<Component> lines,TooltipFlag flag) {
        lines.add(Component.translatable("tooltip.ltw_mobs.locator"));
        var target=stack.get(DataComponents.LODESTONE_TRACKER);
        if(target!=null)target.target().ifPresent(p -> lines.add(Component.translatable("tooltip.ltw_mobs.destination",p.pos().getX(),p.pos().getZ())));
    }
}
