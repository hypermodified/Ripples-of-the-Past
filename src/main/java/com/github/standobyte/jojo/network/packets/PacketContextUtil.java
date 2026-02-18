package com.github.standobyte.jojo.network.packets;

import java.util.function.Supplier;

import javax.annotation.Nullable;

import net.minecraft.entity.player.ServerPlayerEntity;
import net.minecraftforge.fml.network.NetworkEvent;

/**
 * Small adapter layer around Forge packet context access.
 *
 * Porting note: during the 1.20.1 migration this is the only class that should
 * need direct rewiring for context/sender lookups in packet handlers that use it.
 */
public final class PacketContextUtil {
    private PacketContextUtil() {}

    public static void enqueueWorkAndSetHandled(Supplier<NetworkEvent.Context> ctx, Runnable work) {
        NetworkEvent.Context context = ctx.get();
        context.enqueueWork(work);
        context.setPacketHandled(true);
    }

    @Nullable
    public static ServerPlayerEntity getSender(Supplier<NetworkEvent.Context> ctx) {
        return ctx.get().getSender();
    }
}
