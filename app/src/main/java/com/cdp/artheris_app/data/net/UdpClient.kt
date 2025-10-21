package com.cdp.artheris_app.data.net

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

object UdpClient {
    suspend fun send(host: String, port: Int, data: ByteArray) = withContext(Dispatchers.IO) {
        DatagramSocket().use { socket ->
            val address = InetAddress.getByName(host)
            val packet = DatagramPacket(data, data.size, address, port)
            socket.send(packet)
        }
    }
}
