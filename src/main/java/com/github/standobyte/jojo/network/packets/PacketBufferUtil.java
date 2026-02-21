package com.github.standobyte.jojo.network.packets;

import io.netty.buffer.Unpooled;
import net.minecraft.network.PacketBuffer;

/**
 * Buffer helper methods used by packet decode handlers.
 *
 * Porting note: keep buffer copy logic centralized so PacketBuffer/FriendlyByteBuf
 * transitions happen in one place during the 1.20.1 migration.
 */
public final class PacketBufferUtil {
    private PacketBufferUtil() {}

    public static PacketBuffer copyReadableBytes(PacketBuffer source) {
        PacketBuffer copy = new PacketBuffer(Unpooled.buffer(source.readableBytes()));
        copy.writeBytes(source);
        return copy;
    }
}
