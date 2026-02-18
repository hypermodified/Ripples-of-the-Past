package com.github.standobyte.jojo.network.packets.fromserver;

import java.util.function.Supplier;

import com.github.standobyte.jojo.JojoModConfig;
import com.github.standobyte.jojo.network.packets.IModPacketHandler;

import net.minecraft.network.FriendlyByteBuf;

public class ResetSyncedCommonConfigPacket {
    
    public ResetSyncedCommonConfigPacket() {
    }
    
    
    
    public static class Handler implements IModPacketHandler<ResetSyncedCommonConfigPacket> {

        @Override
        public void encode(ResetSyncedCommonConfigPacket msg, FriendlyByteBuf buf) {
        }

        @Override
        public ResetSyncedCommonConfigPacket decode(FriendlyByteBuf buf) {
            return new ResetSyncedCommonConfigPacket();
        }

        @Override
        public void handle(ResetSyncedCommonConfigPacket msg, Supplier<?> ctx) {
            JojoModConfig.Common.SyncedValues.resetConfig();
        }

        @Override
        public Class<ResetSyncedCommonConfigPacket> getPacketClass() {
            return ResetSyncedCommonConfigPacket.class;
        }
    }
}
