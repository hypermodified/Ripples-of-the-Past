package com.github.standobyte.jojo.network.packets;

import java.util.function.Supplier;

import net.minecraft.network.FriendlyByteBuf;

public interface IModPacketHandler<MSG> {
    void encode(MSG msg, FriendlyByteBuf buf);
    
    MSG decode(FriendlyByteBuf buf);
    
    default void enqueueHandleSetHandled(MSG msg, Supplier<?> ctx) {
        Object context = ctx.get();
        invokeMethod(context, "enqueueWork", new Class<?>[] { Runnable.class }, new Object[] { (Runnable) () -> handle(msg, ctx) });
        invokeMethod(context, "setPacketHandled", new Class<?>[] { boolean.class }, new Object[] { true });
    }

    void handle(MSG msg, Supplier<?> ctx);
    
    Class<MSG> getPacketClass();

    static void invokeMethod(Object target, String methodName, Class<?>[] paramTypes, Object[] args) {
        try {
            target.getClass().getMethod(methodName, paramTypes).invoke(target, args);
        }
        catch (ReflectiveOperationException ignored) {}
    }
}
