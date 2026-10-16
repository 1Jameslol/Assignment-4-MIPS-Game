// GUI adapter only. Rules and graphics execute from the MIPS assembly in MARS.
import mars.*;
import mars.mips.hardware.*;
import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.awt.image.BufferedImage;
import java.nio.file.*;
import java.util.ArrayList;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.atomic.AtomicIntegerArray;

@SuppressWarnings("deprecation") // MARS 4.5 exposes its memory bus through Observer.
public class Arcade {
    static final int BASE = 0x10010000;
    final AtomicIntegerArray pixels = new AtomicIntegerArray(128 * 128);
    final ArrayBlockingQueue<Integer> keys = new ArrayBlockingQueue<>(32);
    final MIPSprogram program = new MIPSprogram();
    volatile Throwable failure;
    volatile boolean finished;
    volatile int consumed;

    Arcade(Path source) throws Exception {
        Globals.initialize(false);
        Globals.getSettings().setBooleanSettingNonPersistent(Settings.DELAYED_BRANCHING_ENABLED, false);
        Globals.program = program;
        ArrayList<String> files = new ArrayList<>();
        files.add(source.toAbsolutePath().toString());
        program.assemble(program.prepareFilesForAssembly(files, files.get(0), null), true, false);
        RegisterFile.initializeProgramCounter(true);
        Globals.memory.addObserver((observable, event) -> {
            MemoryAccessNotice notice = (MemoryAccessNotice) event;
            if (notice.getAccessType() == AccessNotice.WRITE) {
                int index = (notice.getAddress() - BASE) >>> 2;
                if (index < pixels.length()) pixels.set(index, notice.getValue());
            }
        }, BASE, BASE + 65532);
        Globals.memory.addObserver((observable, event) -> {
            MemoryAccessNotice notice = (MemoryAccessNotice) event;
            if (notice.getAccessType() == AccessNotice.READ) {
                try {
                    Globals.memory.setRawWord(0xffff0000, 0);
                    consumed++;
                } catch (Exception e) { failure = e; }
            }
        }, 0xffff0004, 0xffff0004);
    }

    Thread start() {
        Thread worker = new Thread(() -> {
            try { program.simulate(-1); }
            catch (Throwable error) { failure = error; }
            finally { finished = true; }
        }, "MIPS game");
        worker.setDaemon(true);
        worker.start();
        return worker;
    }

    void pump() {
        synchronized (Globals.memoryAndRegistersLock) {
            try {
                if (Globals.memory.getWordNoNotify(0xffff0000) == 0) {
                    Integer key = keys.poll();
                    if (key != null) {
                        Globals.memory.setRawWord(0xffff0004, key);
                        Globals.memory.setRawWord(0xffff0000, 1);
                    }
                }
            } catch (Exception e) { failure = e; }
        }
    }

    void window(String name) {
        JFrame frame = new JFrame(name + " — MIPS Arcade");
        BufferedImage image = new BufferedImage(128, 128, BufferedImage.TYPE_INT_RGB);
        JPanel screen = new JPanel() {
            protected void paintComponent(Graphics g) {
                super.paintComponent(g);
                for (int y = 0; y < 128; y++)
                    for (int x = 0; x < 128; x++) image.setRGB(x, y, pixels.get(y * 128 + x));
                g.drawImage(image, 0, 0, getWidth(), getHeight(), null);
            }
        };
        screen.setPreferredSize(new Dimension(512, 512));
        screen.setFocusable(true);
        screen.addKeyListener(new KeyAdapter() {
            public void keyTyped(KeyEvent e) { keys.offer((int) Character.toLowerCase(e.getKeyChar())); }
        });
        screen.addMouseListener(new MouseAdapter() {
            public void mousePressed(MouseEvent e) {
                screen.requestFocusInWindow();
                if (!name.equals("Tic-tac-toe")) return;
                int x = e.getX() * 128 / screen.getWidth();
                int y = e.getY() * 128 / screen.getHeight();
                if (x >= 23 && x < 105 && y >= 29 && y < 99) {
                    int col = Math.min(2, (x - 23) / 28);
                    int row = Math.min(2, (y - 29) / 24);
                    keys.offer((int) '1' + row * 3 + col);
                }
            }
        });
        JPanel buttons = new JPanel();
        if (name.equals("Blackjack")) {
            button(buttons, "Hit (H)", 'h', screen);
            button(buttons, "Stand (S)", 's', screen);
        }
        button(buttons, "Restart (R)", 'r', screen);
        JLabel help = new JLabel(name.equals("Doom")
            ? "W/S move · A/D turn · Z/C strafe · Space shoot · M map"
            : name.equals("Tic-tac-toe") ? "Click a square or press 1–9 · Two players"
            : "H hit · S stand · Dealer stands on soft 17", SwingConstants.CENTER);
        JPanel bottom = new JPanel(new BorderLayout());
        bottom.add(help, BorderLayout.NORTH);
        bottom.add(buttons, BorderLayout.SOUTH);
        frame.add(screen, BorderLayout.CENTER);
        frame.add(bottom, BorderLayout.SOUTH);
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.pack();
        frame.setLocationByPlatform(true);
        frame.setVisible(true);
        screen.requestFocusInWindow();
        Timer timer = new Timer(33, null);
        timer.addActionListener(e -> {
            pump();
            screen.repaint();
            if (finished || failure != null) {
                timer.stop();
                if (failure != null) JOptionPane.showMessageDialog(frame, errorText(failure), "Game error", JOptionPane.ERROR_MESSAGE);
                frame.dispose();
                System.exit(failure == null ? 0 : 1);
            }
        });
        timer.start();
        start();
    }

    void button(JPanel panel, String label, char key, JPanel screen) {
        JButton button = new JButton(label);
        button.addActionListener(e -> { keys.offer((int) key); screen.requestFocusInWindow(); });
        panel.add(button);
    }

    static String errorText(Throwable error) {
        return error instanceof ProcessingException
            ? ((ProcessingException) error).errors().generateErrorAndWarningReport() : error.toString();
    }

    // Exercise the same assembly, framebuffer observer and keyboard handshake
    // without requiring a window server. No gameplay is reimplemented in Java.
    void smoke() throws Exception {
        Thread worker = start();
        long deadline = System.currentTimeMillis() + 10000;
        while (pixels.get(16383) == 0 && !finished && failure == null && System.currentTimeMillis() < deadline)
            Thread.sleep(10);
        if (pixels.get(16383) == 0) throw new AssertionError("No complete GUI framebuffer");
        keys.offer((int) 'r');
        while (consumed < 1 && !finished && failure == null && System.currentTimeMillis() < deadline) {
            pump(); Thread.sleep(10);
        }
        if (consumed < 1) throw new AssertionError("MMIO restart was not consumed");
        keys.offer((int) 'q');
        while (!finished && failure == null && System.currentTimeMillis() < deadline) {
            pump(); Thread.sleep(10);
        }
        worker.join(1000);
        if (failure != null) throw new RuntimeException(errorText(failure));
        if (!finished || consumed < 2) throw new AssertionError("MMIO quit failed");
        System.out.println("GUI SMOKE PASS: MIPS framebuffer, keyboard handshake, restart and quit");
    }

    public static void main(String[] args) throws Exception {
        boolean smoke = args.length > 0 && args[0].equals("--smoke");
        String game = args.length > (smoke ? 1 : 0) ? args[smoke ? 1 : 0] : null;
        if (game == null) {
            String[] choices = {"Doom", "Tic-tac-toe", "Blackjack"};
            int choice = JOptionPane.showOptionDialog(null, "Choose a MIPS game", "MIPS Arcade",
                JOptionPane.DEFAULT_OPTION, JOptionPane.PLAIN_MESSAGE, null, choices, choices[0]);
            if (choice < 0) return;
            game = new String[]{"doom", "tic-tac-toe", "blackjack"}[choice];
        }
        String file, name;
        switch (game) {
            case "doom": file = "doom/doom.asm"; name = "Doom"; break;
            case "tic-tac-toe": file = "tic-tac-toe/tic_tac_toe.asm"; name = "Tic-tac-toe"; break;
            case "blackjack": file = "blackjack/blackjack.asm"; name = "Blackjack"; break;
            default: throw new IllegalArgumentException("Unknown game: " + game);
        }
        Arcade arcade = new Arcade(Path.of(file));
        if (smoke) arcade.smoke();
        else SwingUtilities.invokeLater(() -> arcade.window(name));
    }
}
