package com.github.standobyte.jojo.network.packets.fromserver;

import java.util.function.Supplier;

import com.github.standobyte.jojo.JojoModConfig;
import com.github.standobyte.jojo.network.packets.IModPacketHandler;

import net.minecraft.network.FriendlyByteBuf;

public class CommonConfigPacket {
    private final JojoModConfig.Common.SyncedValues values;
    
    public CommonConfigPacket(JojoModConfig.Common.SyncedValues values) {
        this.values = values;
    }
    
    
    
    public static class Handler implements IModPacketHandler<CommonConfigPacket> {
        
        @Override
        public void encode(CommonConfigPacket msg, FriendlyByteBuf buf) {
            msg.values.writeToBuf(buf);
        }

        @Override
        public CommonConfigPacket decode(FriendlyByteBuf buf) {
            return new CommonConfigPacket(new JojoModConfig.Common.SyncedValues(buf));
        }

        @Override
        public void handle(CommonConfigPacket msg, Supplier<?> ctx) {
            msg.values.changeConfigValues();
        }

        @Override
        public Class<CommonConfigPacket> getPacketClass() {
            return CommonConfigPacket.class;
        }
    }
}
