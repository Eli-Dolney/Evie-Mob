package com.ltw.mobs;

import java.util.UUID;
import javax.annotation.Nullable;
import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.chat.Component;
import net.minecraft.network.syncher.*;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.Mth;
import net.minecraft.world.*;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.effect.*;
import net.minecraft.world.entity.*;
import net.minecraft.world.entity.ai.attributes.*;
import net.minecraft.world.entity.ai.goal.*;
import net.minecraft.world.entity.animal.Animal;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.*;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

public class Companion extends TamableAnimal {
    private static final EntityDataAccessor<Boolean> SADDLED=SynchedEntityData.defineId(Companion.class,EntityDataSerializers.BOOLEAN);
    private static final EntityDataAccessor<Integer> RECOVERY=SynchedEntityData.defineId(Companion.class,EntityDataSerializers.INT);
    private static final EntityDataAccessor<Boolean> FLYING=SynchedEntityData.defineId(Companion.class,EntityDataSerializers.BOOLEAN);
    public final boolean dragon;
    public float flightBlend, oldFlightBlend;
    private int trust;
    private UUID trustingPlayer;
    private BlockPos habitat;
    private RideInput input = new RideInput(0,0,0,false,false,false);
    private int inputTick=-100;
    public Companion(EntityType<? extends Companion> type, Level level, boolean dragon) {
        super(type,level); this.dragon=dragon; setPersistenceRequired();
    }
    public static AttributeSupplier.Builder attributes() { return Mob.createMobAttributes().add(Attributes.MAX_HEALTH,100).add(Attributes.MOVEMENT_SPEED,0.3).add(Attributes.FOLLOW_RANGE,48).add(Attributes.KNOCKBACK_RESISTANCE,1).add(Attributes.STEP_HEIGHT,1.2); }
    @Override protected void defineSynchedData(SynchedEntityData.Builder b) { super.defineSynchedData(b); b.define(SADDLED,false); b.define(RECOVERY,0); b.define(FLYING,false); }
    @Override protected void registerGoals() {
        goalSelector.addGoal(0,new SitWhenOrderedToGoal(this));
        goalSelector.addGoal(5,new LookAtPlayerGoal(this,Player.class,12));
        goalSelector.addGoal(6,new RandomLookAroundGoal(this));
    }
    public boolean saddled() { return entityData.get(SADDLED); }
    public int recovery() { return entityData.get(RECOVERY); }
    public boolean flying() { return entityData.get(FLYING); }
    @Override public boolean isOwnedBy(LivingEntity entity) { return isTame() && entity.getUUID().equals(getOwnerUUID()); }
    public int trust() { return trust; }
    public void setHabitat(BlockPos pos) { habitat=pos.immutable(); }
    @Override public boolean isFood(ItemStack stack) { return stack.is(dragon ? Items.GLOW_BERRIES : Items.TROPICAL_FISH); }
    @Override public boolean canMate(Animal other) { return false; }
    @Override public AgeableMob getBreedOffspring(ServerLevel l, AgeableMob a) { return null; }
    @Override public boolean canDrownInFluidType(net.neoforged.neoforge.fluids.FluidType type) { return dragon && super.canDrownInFluidType(type); }
    @Override public boolean removeWhenFarAway(double d) { return false; }
    @Override public boolean causeFallDamage(float d,float m,DamageSource s) { return false; }
    @Override public boolean isPushedByFluid() { return false; }
    @Override public InteractionResult mobInteract(Player p, InteractionHand hand) {
        ItemStack stack=p.getItemInHand(hand);
        if (level().isClientSide) return InteractionResult.SUCCESS;
        if (recovery()>0) { p.displayClientMessage(Component.translatable("message.ltw_mobs.recovering"),true); return InteractionResult.CONSUME; }
        if (!isTame() && isFood(stack)) {
            if (!p.getUUID().equals(trustingPlayer)) { trustingPlayer=p.getUUID(); trust=0; }
            if (!p.getAbilities().instabuild) stack.shrink(1);
            trust++; level().broadcastEntityEvent(this,(byte)7);
            if (trust>=5) { tame(p); setOrderedToSit(true); p.displayClientMessage(Component.translatable("message.ltw_mobs.tamed",getName()),true); }
            else p.displayClientMessage(Component.translatable("message.ltw_mobs.trust",trust),true);
            return InteractionResult.CONSUME;
        }
        if (!isOwnedBy(p)) { p.displayClientMessage(Component.translatable(isTame()?"message.ltw_mobs.not_owner":"message.ltw_mobs.treat_"+(dragon?"evie":"eli")),true); return InteractionResult.CONSUME; }
        if (isFood(stack)) { if (getHealth()<getMaxHealth()) { heal(12); if(!p.getAbilities().instabuild)stack.shrink(1); level().broadcastEntityEvent(this,(byte)7); } return InteractionResult.CONSUME; }
        if(stack.is(Items.SADDLE) && !saddled()) { entityData.set(SADDLED,true); if(!p.getAbilities().instabuild)stack.shrink(1); return InteractionResult.CONSUME; }
        if(p.isShiftKeyDown()) { setOrderedToSit(!isOrderedToSit()); getNavigation().stop(); p.displayClientMessage(Component.translatable(isOrderedToSit()?"message.ltw_mobs.stay":"message.ltw_mobs.follow"),true); return InteractionResult.CONSUME; }
        if(saddled() && !isVehicle()) { setOrderedToSit(false); p.startRiding(this); }
        else if(!saddled()) p.displayClientMessage(Component.translatable("message.ltw_mobs.saddle"),true);
        return InteractionResult.CONSUME;
    }
    public void acceptInput(RideInput p) {
        if(!Float.isFinite(p.forward()) || !Float.isFinite(p.strafe()) || !Float.isFinite(p.yaw())) return;
        input=new RideInput(Mth.clamp(p.forward(),-1,1),Mth.clamp(p.strafe(),-1,1),Mth.wrapDegrees(p.yaw()),p.up(),p.down(),p.boost()); inputTick=tickCount;
    }
    @Override public boolean isControlledByLocalInstance() { return !level().isClientSide; }
    /** Vanilla vehicle-position packets are disabled; riders send intent through RideInput. */
    @Override @Nullable public LivingEntity getControllingPassenger() { return null; }
    @Nullable public LivingEntity getRider() { return getFirstPassenger() instanceof Player p && isOwnedBy(p) && saddled()?p:null; }
    @Override protected boolean canAddPassenger(Entity p) { return getPassengers().isEmpty() && p instanceof Player player && isOwnedBy(player) && saddled() && recovery()==0; }
    @Override protected void positionRider(Entity rider, Entity.MoveFunction move) {
        Vec3 offset=new Vec3(0,dragon?1.8:2.25,-0.15).yRot(-getYRot()*Mth.DEG_TO_RAD);
        move.accept(rider,getX()+offset.x,getY()+offset.y,getZ()+offset.z);
    }
    @Override public Vec3 getDismountLocationForPassenger(LivingEntity rider) {
        for(int radius=2;radius<=5;radius++) for(int i=0;i<8;i++) {
            double a=i*Math.PI/4; Vec3 p=position().add(Math.cos(a)*radius,1,Math.sin(a)*radius);
            if(level().noCollision(rider,rider.getBoundingBox().move(p.subtract(rider.position())))) return p;
        }
        return position().add(0,getBbHeight()+1,0);
    }
    @Override protected void removePassenger(Entity passenger) {
        protectRider(passenger); super.removePassenger(passenger);
    }
    private void protectRider(Entity passenger) {
        if(passenger instanceof LivingEntity l && !level().isClientSide) {
            l.addEffect(new MobEffectInstance(dragon?MobEffects.SLOW_FALLING:MobEffects.WATER_BREATHING,dragon?6000:1200,0,false,true));
            l.fallDistance=0;
        }
    }
    @Override public boolean hurt(DamageSource source,float amount) {
        if(recovery()>0) return false;
        if(isTame() && amount>=getHealth()) { beginRecovery(); return false; }
        return super.hurt(source,amount);
    }
    @Override public void die(DamageSource source) { if(isTame())beginRecovery(); else super.die(source); }
    private void beginRecovery() { if(recovery()>0)return; entityData.set(RECOVERY,600); setHealth(1); ejectPassengers(); setOrderedToSit(true); getNavigation().stop(); }
    @Override public void tick() {
        super.tick();
        oldFlightBlend=flightBlend;
        flightBlend=Mth.clamp(flightBlend+(flying()?0.08F:-0.08F),0,1);
        if(level().isClientSide)return;
        if(habitat==null)habitat=blockPosition();
        if(recovery()>0) { entityData.set(RECOVERY,recovery()-1); if(recovery()==0)setHealth(getMaxHealth()); }
        if(isTame() && getY()<level().getMinBuildHeight()+4) { beginRecovery(); teleportTo(habitat.getX()+0.5,habitat.getY()+1,habitat.getZ()+0.5); }
        if(getRider() instanceof Player p && !dragon && isInWater()) {
            p.addEffect(new MobEffectInstance(MobEffects.WATER_BREATHING,220,0,false,false));
            p.addEffect(new MobEffectInstance(MobEffects.NIGHT_VISION,220,0,false,false));
        }
        if(!dragon && !isInWater() && tickCount%40==0) setAirSupply(getMaxAirSupply());
    }
    @Override public void travel(Vec3 ignored) {
        if(level().isClientSide) { calculateEntityAnimation(false); return; } // Server-owned simulation.
        Vec3 desired=Vec3.ZERO;
        boolean rider=getRider()!=null && recovery()==0;
        if(rider) {
            RideInput p=tickCount-inputTick<=10?input:new RideInput(0,0,getYRot(),false,false,false);
            setYRot(p.yaw()); yBodyRot=getYRot(); yHeadRot=getYRot();
            if(dragon && p.up())entityData.set(FLYING,true);
            if(dragon && onGround() && !p.up())entityData.set(FLYING,false);
            double speed=dragon?(flying()?Settings.FLIGHT_SPEED.get():0.24):(isInWater()?Settings.SWIM_SPEED.get():0.035);
            if(p.boost())speed*=1.6;
            Vec3 horizontal=new Vec3(p.strafe()*0.65,0,p.forward()); if(horizontal.lengthSqr()>1)horizontal=horizontal.normalize();
            desired=horizontal.yRot(-getYRot()*Mth.DEG_TO_RAD).scale(speed);
            if((dragon&&flying()) || (!dragon&&isInWater()))desired=desired.add(0,(p.up()?1:0)*speed*0.65-(p.down()?1:0)*speed*0.65,0);
        } else if(!isOrderedToSit() && recovery()==0) {
            LivingEntity owner=getOwner();
            Vec3 target=owner!=null?owner.position():Vec3.atCenterOf(habitat==null?blockPosition():habitat);
            double distance=position().distanceTo(target);
            if(distance>(owner!=null?6:10)) {
                if(dragon) { entityData.set(FLYING,!onGround()||target.y>getY()+2||distance>12); desired=target.subtract(position()).normalize().scale(flying()?0.38:0.18); }
                else if(isInWater()) { Vec3 next=position().add(target.subtract(position()).normalize().scale(3)); if(level().getFluidState(BlockPos.containing(next)).is(net.minecraft.tags.FluidTags.WATER))desired=target.subtract(position()).normalize().scale(0.35); }
                if(desired.horizontalDistanceSqr()>0.001) { setYRot((float)(Mth.atan2(-desired.x,desired.z)*Mth.RAD_TO_DEG)); yBodyRot=getYRot();yHeadRot=getYRot(); }
            } else if(dragon && onGround())entityData.set(FLYING,false);
        }
        boolean hover=dragon&&flying()&&recovery()==0&&!isOrderedToSit();
        setNoGravity(hover||(!dragon&&isInWater()));
        Vec3 velocity=getDeltaMovement().lerp(desired,0.25);
        if(!isNoGravity())velocity=velocity.add(0,-0.08,0);
        if(!dragon && isInWater() && !rider && desired==Vec3.ZERO)velocity=velocity.scale(0.8);
        setDeltaMovement(velocity); move(MoverType.SELF,velocity);
        if(horizontalCollision)setDeltaMovement(0,getDeltaMovement().y,0);
        if(verticalCollision)setDeltaMovement(getDeltaMovement().x,0,getDeltaMovement().z);
        calculateEntityAnimation(false);
    }
    @Override public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);tag.putInt("Trust",trust);if(trustingPlayer!=null)tag.putUUID("TrustingPlayer",trustingPlayer);
        tag.putBoolean("Saddled",saddled());tag.putInt("Recovery",recovery());tag.putBoolean("Flying",flying());if(habitat!=null)tag.putLong("Habitat",habitat.asLong());
    }
    @Override public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag); trust=tag.getInt("Trust");trustingPlayer=tag.hasUUID("TrustingPlayer")?tag.getUUID("TrustingPlayer"):null;
        entityData.set(SADDLED,tag.getBoolean("Saddled"));entityData.set(RECOVERY,tag.getInt("Recovery"));entityData.set(FLYING,tag.getBoolean("Flying"));if(tag.contains("Habitat"))habitat=BlockPos.of(tag.getLong("Habitat"));
    }
}
