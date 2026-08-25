package org.chotki.core

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.util.UUID

/**
 * Lower case going out, either case coming in.
 *
 * `UUID.toString` is lower case and `UUID.fromString` accepts both, so reading
 * is already forgiving; writing is pinned here so the form in a backup file is
 * settled rather than incidental. Swift writes upper case, which is one of
 * several reasons the two platforms' backups are not interchangeable.
 */
object UuidSerializer : KSerializer<UUID> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("UUID", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: UUID) =
        encoder.encodeString(value.toString())

    override fun deserialize(decoder: Decoder): UUID {
        val text = decoder.decodeString()
        return try {
            UUID.fromString(text)
        } catch (e: IllegalArgumentException) {
            error("not an id: $text")
        }
    }
}
