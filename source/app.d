module app;

import dlangui;
import std.stdio;
import std.string;
import std.conv;
import core.time;

// Windows API for memory metrics
version(Windows)
{
    import core.sys.windows.windows;
    import core.sys.windows.psapi;
    
    extern(Windows) BOOL GlobalMemoryStatusEx(LPMEMORYSTATUSEX lpBuffer);
    
    struct MEMORYSTATUSEX {
        DWORD dwLength;
        DWORD dwMemoryLoad;
        DWORDLONG ullTotalPhys;
        DWORDLONG ullAvailPhys;
        DWORDLONG ullTotalPageFile;
        DWORDLONG ullAvailPageFile;
        DWORDLONG ullTotalVirtual;
        DWORDLONG ullAvailVirtual;
        DWORDLONG ullAvailExtendedVirtual;
    }
}

class LoadMetricWidget : Widget
{
    private double currentRamPercent = 0.0;
    private double hardFaultFreq = 0.0;
    private bool hardFaultFlash = false;
    private long lastHardFaultCount = 0;
    
    this() {
        super("LoadMetricWidget");
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        // Start a timer to read system metrics every 500ms
        Platform.instance.setTimer(this, 1, 500); 
    }
    
    override bool onTimer(ulong id) {
        if (id == 1) {
            updateMetrics();
            invalidate(); // Request redraw
            return true;
        }
        return super.onTimer(id);
    }
    
    void updateMetrics() {
        version(Windows) {
            MEMORYSTATUSEX memInfo;
            memInfo.dwLength = memInfo.sizeof;
            if (GlobalMemoryStatusEx(&memInfo)) {
                // Percentage of physical memory in use (0-100)
                currentRamPercent = memInfo.dwMemoryLoad;
            }
            
            // Note: True hard fault fetching globally requires ETW or PDH (Performance Data Helper)
            // For the sake of the HUD prototype, we will simulate the hard fault event checks.
            // A real ETW/PDH implementation would replace this logic.
            // Simulating a 5% chance of a hard fault spike
            import std.random;
            if (uniform(0, 100) < 5) {
                hardFaultFreq += 0.2; // Increases red saturation
                if (hardFaultFreq > 1.0) hardFaultFreq = 1.0;
                hardFaultFlash = true;
            } else {
                hardFaultFreq -= 0.05; // Decay
                if (hardFaultFreq < 0.0) hardFaultFreq = 0.0;
                hardFaultFlash = false;
            }
        }
    }
    
    override void onDraw(DrawBuf buf) {
        super.onDraw(buf);
        
        Rect rc = _pos;
        
        // 1. Draw Semi-Transparent Dark Background (simulating vignette overlay at the edges)
        // Dlangui defines colors in ARGB: 0xAARRGGBB
        uint bgColor = 0xAA101010; 
        buf.fillRect(rc, bgColor);
        
        // Vignette approximation: drawing darker rects fading inward 
        // A true vignette requires a shader or radial gradient across the buf frame.
        buf.fillRect(Rect(rc.left, rc.top, rc.right, rc.top + 5), 0x55000000);
        buf.fillRect(Rect(rc.left, rc.bottom - 5, rc.right, rc.bottom), 0x55000000);
        
        // 2. Draw RAM % Text
        string text = format("RAM: %.1f%%", currentRamPercent);
        FontRef font = FontManager.instance.getFont(24, 400, false, FontFamily.SansSerif, "");
        buf.drawText(rc.left + 15, rc.top + 15, dtext(text), 0xFFFFFFFF, font);
        
        // 3. Draw Hard Fault Zone (Small zone at the right)
        Rect faultZone = Rect(rc.right - 80, rc.top, rc.right, rc.bottom);
        
        // Grow/decay red saturation based on frequency (hardFaultFreq goes from 0.0 to 1.0)
        ubyte redChannel = cast(ubyte)(hardFaultFreq * 255);
        uint redColor = (0x80 << 24) | (redChannel << 16) | 0x0000; // Semi-transparent red base
        buf.fillRect(faultZone, redColor);
        
        // Flash a yellow transparent overlay if a hard fault just occurred
        if (hardFaultFlash) {
            uint flashColor = 0x88FFFF00; // Semi-transparent yellow
            buf.fillRect(faultZone, flashColor);
        }
    }
}

extern (C) int UIAppMain(string[] args)
{
    // Configure Platform to prefer OpenGL
    Platform.instance.uiLanguage = "en";
    Platform.instance.uiTheme = "theme_dark";

    // Setup borderless and essentially transparent HUD window configurations
    // Some platforms require WS_EX_LAYERED for true transparency. 
    uint winFlags = WindowFlag.Borderless | WindowFlag.AlwaysOnTop; 
    
    // Create the borderless window 
    // Positioned somewhat bottom right. In a real app we query display size here.
    Window window = Platform.instance.createWindow("GraphRAG Indexer HUD", null, winFlags, 300, 80);
    
    window.mainWidget = new LoadMetricWidget();
    window.show();

    return Platform.instance.enterMessageLoop();
}
