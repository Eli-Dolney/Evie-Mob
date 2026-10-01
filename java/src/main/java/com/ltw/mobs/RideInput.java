package com.ltw.mobs;
import net.minecraft.network.RegistryFriendlyByteBuf;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;
import net.neoforged.neoforge.network.event.RegisterPayloadHandlersEvent;

/** Only intent crosses the network; position and speed are determined by the server. */
public record RideInput(float forward, float strafe, float yaw, boolean up, boolean down, boolean boost) implements CustomPacketPayload {
    public static final Type<RideInput> TYPE = new Type<>(LtwMobs.id("ride_input"));
    public static final StreamCodec<RegistryFriendlyByteBuf,RideInput> CODEC=StreamCodec.of(
        (b,p) -> { b.writeFloat(p.forward); b.writeFloat(p.strafe); b.writeFloat(p.yaw); b.writeBoolean(p.up); b.writeBoolean(p.down); b.writeBoolean(p.boost); },
        b -> new RideInput(b.readFloat(),b.readFloat(),b.readFloat(),b.readBoolean(),b.readBoolean(),b.readBoolean()));
    public Type<? extends CustomPacketPayload> type() { return TYPE; }
    public static void register(RegisterPayloadHandlersEvent e) {
        e.registrar("1").playToServer(TYPE,CODEC,(p,ctx) -> ctx.enqueueWork(() -> {
            if (ctx.player().getVehicle() instanceof Companion c && c.getRider() == ctx.player() && c.isOwnedBy(ctx.player())) c.acceptInput(p);
        }));
    }
}
