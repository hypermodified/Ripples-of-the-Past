package com.github.standobyte.jojo.network.packets.fromclient;

import java.util.function.Supplier;

import com.github.standobyte.jojo.entity.SoulEntity;
import com.github.standobyte.jojo.network.packets.IModPacketHandler;
import com.github.standobyte.jojo.network.packets.PacketContextUtil;

import net.minecraft.entity.Entity;
import net.minecraft.entity.player.ServerPlayerEntity;
import net.minecraft.network.PacketBuffer;
import net.minecraftforge.fml.network.NetworkEvent;

public class ClRemovePlayerSoulEntityPacket {
    private final int soulEntityId;
    
    public ClRemovePlayerSoulEntityPacket(int soulEntityId) {
        this.soulEntityId = soulEntityId;
    }
    
    
    
    public static class Handler implements IModPacketHandler<ClRemovePlayerSoulEntityPacket> {

        @Override
        public void encode(ClRemovePlayerSoulEntityPacket msg, PacketBuffer buf) {
            buf.writeInt(msg.soulEntityId);
        }

        @Override
        public ClRemovePlayerSoulEntityPacket decode(PacketBuffer buf) {
            return new ClRemovePlayerSoulEntityPacket(buf.readInt());
        }

        @Override
        public void handle(ClRemovePlayerSoulEntityPacket msg, Supplier<NetworkEvent.Context> ctx) {
            ServerPlayerEntity player = PacketContextUtil.getSender(ctx);
            if (player == null) {
                return;
            }
            Entity entity = player.level.getEntity(msg.soulEntityId);
            if (entity instanceof SoulEntity) {
                ((SoulEntity) entity).skipAscension();
            }
        }

        @Override
        public Class<ClRemovePlayerSoulEntityPacket> getPacketClass() {
            return ClRemovePlayerSoulEntityPacket.class;
        }
    }
}
