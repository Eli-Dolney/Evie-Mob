package com.ltw.mobs.client;

import com.ltw.mobs.Companion;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.minecraft.client.model.EntityModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.util.Mth;

/** Animation rig for the two original Blockbench models. All rendering stays client-side. */
public final class CompanionModel extends EntityModel<Companion> {
    private final ModelPart root, body, head, jaw, saddle, tailRoot, tailFin;
    private final ModelPart[] tailSegments;
    private final ModelPart[] limbs = new ModelPart[4];
    private final ModelPart leftWing, rightWing, leftWrist, rightWrist;
    private final boolean dragon;

    public CompanionModel(ModelPart root, boolean dragon) {
        this.root = root;
        this.dragon = dragon;
        this.body = root.getChild(dragon ? "torso" : "body");
        this.head = dragon ? body.getChild("neck").getChild("head") : body.getChild("head");
        this.jaw = dragon ? null : head.getChild("jaw");
        this.saddle = body.getChild("saddle");
        this.tailRoot = body.getChild("tail_root");
        this.tailSegments = new ModelPart[dragon ? 5 : 4];
        for (int i = 0; i < tailSegments.length; i++) {
            tailSegments[i] = tailRoot.getChild(dragon ? "tail_" + i : "tail_segment_" + i);
        }
        this.tailFin = dragon ? null : tailRoot.getChild("caudal_fin");
        if (dragon) {
            limbs[0] = body.getChild("front_left");
            limbs[1] = body.getChild("front_right");
            limbs[2] = body.getChild("rear_left");
            limbs[3] = body.getChild("rear_right");
            leftWing = body.getChild("left_wing");
            rightWing = body.getChild("right_wing");
            leftWrist = leftWing.getChild("wrist");
            rightWrist = rightWing.getChild("wrist");
        } else {
            limbs[0] = body.getChild("front_left_flipper");
            limbs[1] = body.getChild("front_right_flipper");
            limbs[2] = body.getChild("rear_left_flipper");
            limbs[3] = body.getChild("rear_right_flipper");
            leftWing = rightWing = leftWrist = rightWrist = null;
        }
    }

    public static LayerDefinition create(boolean dragon) {
        return dragon ? EvieGeometry.create() : EliGeometry.create();
    }

    @Override
    public void setupAnim(Companion entity, float walk, float amount, float age, float yaw, float pitch) {
        root.getAllParts().forEach(ModelPart::resetPose);
        saddle.visible = entity.saddled();
        head.yRot = yaw * Mth.DEG_TO_RAD * 0.35F;
        head.xRot = pitch * Mth.DEG_TO_RAD * 0.25F;
        float motion = Mth.clamp(entity.walkAnimation.speed() * 2, 0, 1);
        float wave = Mth.sin(age * (dragon ? 0.13F : 0.18F));
        tailRoot.yRot = wave * (dragon ? 0.10F : 0.17F + motion * 0.13F);
        tailRoot.yRot += Mth.clamp(Mth.wrapDegrees(entity.getYRot() - entity.yRotO) * 0.025F, -0.3F, 0.3F);
        for (int i = 0; i < tailSegments.length; i++) {
            tailSegments[i].yRot = Mth.sin(age * (dragon ? 0.12F : 0.19F) - i * 0.55F)
                    * (dragon ? 0.10F : 0.20F + motion * 0.12F);
        }

        if (dragon) {
            float blend = Mth.lerp(Mth.clamp(age - entity.tickCount, 0, 1),
                    entity.oldFlightBlend, entity.flightBlend);
            float flap = Mth.sin(age * 0.3F) * 0.5F;
            leftWing.zRot = Mth.lerp(blend, -0.95F + wave * 0.025F, flap);
            rightWing.zRot = -leftWing.zRot;
            leftWing.yRot = Mth.lerp(blend, -0.25F, -0.08F);
            rightWing.yRot = -leftWing.yRot;
            leftWrist.zRot = Mth.lerp(blend, -0.20F, flap * 0.30F);
            rightWrist.zRot = -leftWrist.zRot;
            for (int i = 0; i < 4; i++) {
                float step = Mth.cos(walk * 0.65F + ((i == 0 || i == 3) ? 0 : Mth.PI))
                        * amount * 0.7F;
                limbs[i].xRot = Mth.lerp(blend, step, 0.55F);
            }
            body.y += blend * wave * 0.8F;
            if (entity.isInSittingPose() || entity.recovery() > 0) {
                body.y += 9;
                for (ModelPart limb : limbs) limb.xRot = -0.95F;
                head.xRot += 0.14F;
            }
        } else {
            jaw.xRot = 0.04F + Math.max(0, Mth.sin(age * 0.045F)) * 0.09F
                    + (entity.isVehicle() ? motion * 0.08F : 0);
            body.zRot = Mth.sin(age * 0.08F) * 0.025F;
            for (int i = 0; i < 4; i++) {
                int side = i % 2 == 0 ? 1 : -1;
                limbs[i].zRot = side * (0.08F + wave * 0.10F);
                limbs[i].yRot = side * (0.12F + Mth.sin(age * 0.13F + i) * 0.15F);
                limbs[i].getChild("blade").zRot = side * Mth.sin(age * 0.14F + i) * 0.10F;
            }
            tailFin.yRot = Mth.sin(age * 0.20F - 2.5F) * (0.18F + motion * 0.2F);
            if (entity.recovery() > 0) body.zRot = 0.12F;
        }
    }

    @Override
    public void renderToBuffer(PoseStack pose, VertexConsumer vertices, int light, int overlay, int color) {
        root.render(pose, vertices, light, overlay, color);
    }
}
