package com.github.standobyte.jojo.network.packets;

import java.util.function.Supplier;

import net.minecraft.network.PacketBuffer;
import net.minecraftforge.fml.network.NetworkEvent;

public interface IModPacketHandler<MSG> {
    void encode(MSG msg, PacketBuffer buf);
    
    MSG decode(PacketBuffer buf);
    
    default void enqueueHandleSetHandled(MSG msg, Supplier<NetworkEvent.Context> ctx) {
        PacketContextUtil.enqueueWorkAndSetHandled(ctx, () -> handle(msg, ctx));
    }
    void handle(MSG msg, Supplier<NetworkEvent.Context> ctx);
    
    Class<MSG> getPacketClass();
}
