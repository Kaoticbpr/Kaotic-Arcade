import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;

/**
 * Drives RetroArch's UDP network gamepad from the PC, speaking the same wire format
 * P2BridgeService uses on the cabinet (struct remote_message, little endian, 20 bytes:
 * int port; int device; int index; int id; uint16_t state; +2 pad -- to 55400 + user).
 *
 * Exists so coin and Start timing can be varied and measured against what the game actually
 * counts, instead of guessing at the physical panel. Requires network_remote_enable in the
 * RetroArch config, which cabinet.cfg already sets.
 *
 *   java Pad.java &lt;host&gt; &lt;user&gt; coin      &lt;n&gt; &lt;onMs&gt; &lt;offMs&gt;
 *   java Pad.java &lt;host&gt; &lt;user&gt; start     &lt;holdMs&gt;
 *   java Pad.java &lt;host&gt; &lt;user&gt; coinstart &lt;n&gt; &lt;onMs&gt; &lt;offMs&gt; &lt;holdMs&gt;
 *   java Pad.java &lt;host&gt; &lt;user&gt; press     &lt;id&gt; &lt;holdMs&gt;
 */
public class Pad {

    static final int BASE_PORT = 55400;
    static final int RETRO_DEVICE_JOYPAD = 1;
    static final int ID_SELECT = 2, ID_START = 3;

    static DatagramSocket sock;
    static InetAddress host;
    static int user;

    public static void main(String[] a) throws Exception {
        host = InetAddress.getByName(a[0]);
        user = Integer.parseInt(a[1]);
        String cmd = a[2];
        sock = new DatagramSocket();

        if (cmd.equals("coin")) {
            coins(Integer.parseInt(a[3]), Integer.parseInt(a[4]), Integer.parseInt(a[5]));
        } else if (cmd.equals("start")) {
            pulse(ID_START, Integer.parseInt(a[3]));
        } else if (cmd.equals("coinstart")) {
            coins(Integer.parseInt(a[3]), Integer.parseInt(a[4]), Integer.parseInt(a[5]));
            pulse(ID_START, Integer.parseInt(a[6]));
        } else if (cmd.equals("press")) {
            pulse(Integer.parseInt(a[3]), Integer.parseInt(a[4]));
        } else {
            System.err.println("unknown command: " + cmd);
            System.exit(2);
        }
        sock.close();
        System.out.println("sent");
    }

    static void coins(int n, int on, int off) throws Exception {
        for (int i = 0; i < n; i++) {
            pulse(ID_SELECT, on);
            Thread.sleep(off);
        }
    }

    static void pulse(int id, int holdMs) throws Exception {
        send(id, 1);
        Thread.sleep(holdMs);
        send(id, 0);
    }

    static void send(int id, int state) throws Exception {
        byte[] p = new byte[20];
        putInt(p, 0, 0);
        putInt(p, 4, RETRO_DEVICE_JOYPAD);
        putInt(p, 8, 0);
        putInt(p, 12, id);
        p[16] = (byte) (state & 0xFF);
        p[17] = (byte) ((state >> 8) & 0xFF);
        sock.send(new DatagramPacket(p, p.length, host, BASE_PORT + user));
    }

    static void putInt(byte[] b, int off, int v) {
        b[off] = (byte) v;
        b[off + 1] = (byte) (v >> 8);
        b[off + 2] = (byte) (v >> 16);
        b[off + 3] = (byte) (v >> 24);
    }
}
