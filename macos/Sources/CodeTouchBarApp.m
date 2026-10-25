#import <AppKit/AppKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Security.h>
#import <CoreAudio/CoreAudio.h>
#import <IOKit/hidsystem/ev_keymap.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <math.h>

static NSString * const kTrayIdentifier = @"com.codetouchbar.studio.usage";

// Tecla ESC virtual (vital para a Touch Bar física)
static NSString * const kEscItem = @"com.codetouchbar.studio.esc";

// Modelos LLM
static NSString * const kCodexItem = @"com.codetouchbar.studio.codex";
static NSString * const kClaudeItem = @"com.codetouchbar.studio.claude";
static NSString * const kAntigravityItem = @"com.codetouchbar.studio.antigravity";
static NSString * const kGeminiItem = @"com.codetouchbar.studio.gemini";
static NSString * const kDeepseekItem = @"com.codetouchbar.studio.deepseek";
static NSString * const kOllamaItem = @"com.codetouchbar.studio.ollama";
static NSString * const kPerplexityItem = @"com.codetouchbar.studio.perplexity";

// Ações Globais
static NSString * const kRefreshItem = @"com.codetouchbar.studio.refresh";
static NSString * const kCloseItem = @"com.codetouchbar.studio.close";

// Alternador de Controles do Sistema
static NSString * const kControlsToggleItem = @"com.codetouchbar.studio.controls-toggle";
static NSString * const kControlsBackItem = @"com.codetouchbar.studio.controls-back";

// Controles de Hardware do macOS (Brilho, Mídia e Volume)
static NSString * const kBrightnessDownItem = @"com.codetouchbar.studio.brightness-down";
static NSString * const kBrightnessUpItem = @"com.codetouchbar.studio.brightness-up";
static NSString * const kMediaPrevItem = @"com.codetouchbar.studio.media-prev";
static NSString * const kMediaPlayPauseItem = @"com.codetouchbar.studio.media-playpause";
static NSString * const kMediaNextItem = @"com.codetouchbar.studio.media-next";
static NSString * const kVolumeMuteItem = @"com.codetouchbar.studio.volume-mute";
static NSString * const kVolumeDownItem = @"com.codetouchbar.studio.volume-down";
static NSString * const kVolumeUpItem = @"com.codetouchbar.studio.volume-up";

// Itens da barra de detalhes do modelo selecionado na Touch Bar
static NSString * const kBackItem = @"com.codetouchbar.studio.back";
static NSString * const kDetailInfoItem = @"com.codetouchbar.studio.detail-info";
static NSString * const kOpenAppItem = @"com.codetouchbar.studio.open-app";

#pragma mark - HUD Informativo de Mídia

@interface CodeTouchBarHUDController : NSObject
+ (instancetype)sharedHUD;
- (void)showMediaHUDWithAction:(NSString *)action iconName:(NSString *)iconName subtitle:(NSString *)subtitle;
@end

@interface CodeTouchBarHUDController ()
@property (nonatomic, strong) NSPanel *window;
@property (nonatomic, strong) NSImageView *iconView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *valueLabel;
@property (nonatomic, strong) NSView *progressTrackView;
@property (nonatomic, strong) NSView *progressFillView;
@property (nonatomic, strong) NSTimer *dismissTimer;
@end

@implementation CodeTouchBarHUDController

+ (instancetype)sharedHUD {
    static CodeTouchBarHUDController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CodeTouchBarHUDController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSRect frame = NSMakeRect(0, 0, 220, 130);
        self.window = [[NSPanel alloc] initWithContentRect:frame
                                                 styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
        self.window.level = NSScreenSaverWindowLevel;
        self.window.backgroundColor = [NSColor clearColor];
        self.window.opaque = NO;
        self.window.hasShadow = YES;
        self.window.ignoresMouseEvents = YES;

        NSVisualEffectView *vev = [[NSVisualEffectView alloc] initWithFrame:frame];
        vev.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        vev.material = NSVisualEffectMaterialHUDWindow;
        vev.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        vev.state = NSVisualEffectStateActive;
        vev.wantsLayer = YES;
        vev.layer.cornerRadius = 20.0;
        vev.layer.masksToBounds = YES;
        vev.layer.borderWidth = 1.0;
        vev.layer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.18].CGColor;
        [self.window.contentView addSubview:vev];

        self.iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(85, 68, 50, 44)];
        self.iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
        self.iconView.contentTintColor = [NSColor whiteColor];
        [vev addSubview:self.iconView];

        self.titleLabel = [NSTextField labelWithString:@""];
        self.titleLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
        self.titleLabel.textColor = [NSColor whiteColor];
        self.titleLabel.alignment = NSTextAlignmentCenter;
        self.titleLabel.frame = NSMakeRect(10, 44, 200, 20);
        [vev addSubview:self.titleLabel];

        self.progressTrackView = [[NSView alloc] initWithFrame:NSMakeRect(25, 24, 170, 7)];
        self.progressTrackView.wantsLayer = YES;
        self.progressTrackView.layer.cornerRadius = 3.5;
        self.progressTrackView.layer.masksToBounds = YES;
        self.progressTrackView.layer.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.25].CGColor;
        [vev addSubview:self.progressTrackView];

        self.progressFillView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 85, 7)];
        self.progressFillView.wantsLayer = YES;
        self.progressFillView.layer.cornerRadius = 3.5;
        self.progressFillView.layer.backgroundColor = [NSColor whiteColor].CGColor;
        [self.progressTrackView addSubview:self.progressFillView];

        self.valueLabel = [NSTextField labelWithString:@""];
        self.valueLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightMedium];
        self.valueLabel.textColor = [NSColor colorWithWhite:0.95 alpha:1.0];
        self.valueLabel.alignment = NSTextAlignmentCenter;
        self.valueLabel.frame = NSMakeRect(10, 6, 200, 16);
        [vev addSubview:self.valueLabel];
    }
    return self;
}

- (void)presentHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSScreen *screen = [NSScreen mainScreen];
        if (screen) {
            NSRect sFrame = screen.visibleFrame;
            CGFloat x = sFrame.origin.x + (sFrame.size.width - 220) / 2.0;
            CGFloat y = sFrame.origin.y + (sFrame.size.height - 130) * 0.28;
            [self.window setFrameOrigin:NSMakePoint(x, y)];
        }
        self.window.alphaValue = 1.0;
        [self.window orderFrontRegardless];

        [self.dismissTimer invalidate];
        self.dismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.2 repeats:NO block:^(NSTimer *t) {
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.25;
                self.window.animator.alphaValue = 0.0;
            } completionHandler:^{
                if (self.window.alphaValue == 0.0) {
                    [self.window orderOut:nil];
                }
            }];
        }];
    });
}

- (void)showMediaHUDWithAction:(NSString *)action iconName:(NSString *)iconName subtitle:(NSString *)subtitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.iconView.image = [NSImage imageWithSystemSymbolName:iconName accessibilityDescription:action];
        self.titleLabel.stringValue = action;
        self.progressTrackView.hidden = YES;
        self.valueLabel.stringValue = subtitle ?: @"Controle de Mídia";
        [self presentHUD];
    });
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTouchBarDelegate, NSWindowDelegate, NSTouchBarProvider, NSMenuDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenu *statusMenu;
@property(nonatomic, strong) NSWindow *controlWindow;
@property(nonatomic, strong) NSTouchBar *touchBar;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *statuses;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *providerMetrics;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic, strong) NSMutableDictionary *settings;
@property(nonatomic, strong) NSWindow *preferencesWindow;
@property(nonatomic, assign) BOOL refreshInProgress;

// Touch Bar - Estado e Navegação
@property(nonatomic, strong) NSCustomTouchBarItem *trayItem;
@property(nonatomic, strong) NSButton *trayButton;
@property(nonatomic, strong) NSTouchBar *modalTouchBar;
@property(nonatomic, strong) dispatch_queue_t audioControlQueue;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSHashTable<NSButton *> *> *touchBarProviderButtons;
@property(nonatomic, strong) NSHashTable<NSButton *> *touchBarDetailInfoButtons;
@property(nonatomic, assign) BOOL isModalTouchBarPresented;
@property(nonatomic, assign) BOOL showSystemControls;
@property(nonatomic, copy) NSString *activeDetailProvider;

// Preferências - Aba 1: Geral
@property(nonatomic, strong) NSDictionary<NSString *, NSButton *> *providerCheckboxes;
@property(nonatomic, strong) NSPopUpButton *refreshIntervalPopup;
@property(nonatomic, strong) NSButton *launchAtLoginCheckbox;
@property(nonatomic, strong) NSButton *keepInMenuBarCheckbox;
@property(nonatomic, strong) NSSecureTextField *deepseekAPIKeyField;

// Preferências - Aba 2: Limites e Alertas
@property(nonatomic, strong) NSPopUpButton *limitWindowPopup;
@property(nonatomic, strong) NSPopUpButton *antigravityModePopup;
@property(nonatomic, strong) NSPopUpButton *warningThresholdPopup;
@property(nonatomic, strong) NSPopUpButton *criticalThresholdPopup;
@property(nonatomic, strong) NSButton *showResetTimeCheckbox;
@property(nonatomic, strong) NSButton *notificationsCheckbox;

// Controle de Notificações
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *notifiedProviders;

// Componentes dinâmicos da janela de controle
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSTextField *> *controlWindowValueLabels;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSButton *> *controlWindowOpenButtons;
@property(nonatomic, strong) NSTextField *controlWindowLastSyncLabel;
@property(nonatomic, strong) NSDate *lastRefreshDate;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.statuses = [@{
        @"codex": @"--",
        @"claude": @"--",
        @"antigravity": @"--",
        @"gemini": @"--",
        @"deepseek": @"--",
        @"ollama": @"--",
        @"perplexity": @"--"
    } mutableCopy];
    self.providerMetrics = [NSMutableDictionary dictionary];
    self.notifiedProviders = [NSMutableDictionary dictionary];
    self.touchBarProviderButtons = [NSMutableDictionary dictionary];
    self.touchBarDetailInfoButtons = [NSHashTable weakObjectsHashTable];
    self.audioControlQueue = dispatch_queue_create("com.codetouchbar.studio.audio-control", DISPATCH_QUEUE_SERIAL);
    self.isModalTouchBarPresented = NO;
    self.showSystemControls = NO;
    self.activeDetailProvider = nil;
    [self loadSettings];
    [self buildMenuBarItem];
    [self registerTouchBarEntry];
    [self updateAppTouchBar];
    [self refreshStatuses];
    [self configureRefreshTimer];
    [self showControlWindow];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.refreshTimer invalidate];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    (void)sender;
    (void)flag;
    [self showControlWindow];
    return YES;
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [sender orderOut:nil];
    [self updateMenuBarMenu];
    return NO;
}

#pragma mark - Provedores e Metadados

- (NSArray<NSString *> *)allProviders {
    return @[@"codex", @"claude", @"antigravity", @"gemini", @"deepseek", @"ollama", @"perplexity"];
}

- (NSString *)displayNameForProvider:(NSString *)provider {
    if ([provider isEqualToString:@"codex"]) return @"OpenAI Codex";
    if ([provider isEqualToString:@"claude"]) return @"Anthropic Claude";
    if ([provider isEqualToString:@"antigravity"]) return @"Antigravity";
    if ([provider isEqualToString:@"gemini"]) return @"Google Gemini";
    if ([provider isEqualToString:@"deepseek"]) return @"DeepSeek AI";
    if ([provider isEqualToString:@"ollama"]) return @"Ollama (Local)";
    if ([provider isEqualToString:@"perplexity"]) return @"Perplexity AI";
    return provider;
}

- (NSString *)appNameForProvider:(NSString *)provider {
    if ([provider isEqualToString:@"codex"]) return @"ChatGPT";
    if ([provider isEqualToString:@"claude"]) return @"Claude";
    if ([provider isEqualToString:@"antigravity"]) return @"Antigravity";
    if ([provider isEqualToString:@"gemini"]) return @"Gemini";
    if ([provider isEqualToString:@"deepseek"]) return @"DeepSeek";
    if ([provider isEqualToString:@"ollama"]) return @"Ollama";
    if ([provider isEqualToString:@"perplexity"]) return @"Perplexity";
    return provider;
}

- (NSString *)subtitleForProvider:(NSString *)provider {
    if ([provider isEqualToString:@"codex"]) return @"Sessão 5h / Quota semanal";
    if ([provider isEqualToString:@"claude"]) return @"Histórico local do Claude Desktop";
    if ([provider isEqualToString:@"antigravity"]) return @"Cota do Language Server local";
    if ([provider isEqualToString:@"gemini"]) return @"Cota pessoal sem API documentada";
    if ([provider isEqualToString:@"deepseek"]) return @"Saldo da API (configure uma chave)";
    if ([provider isEqualToString:@"ollama"]) return @"Daemon Local (127.0.0.1:11434)";
    if ([provider isEqualToString:@"perplexity"]) return @"Cota pessoal sem API documentada";
    return @"";
}

- (NSString *)detailDescriptionForProvider:(NSString *)provider {
    if ([provider isEqualToString:@"antigravity"]) {
        NSArray *windows = self.providerMetrics[provider][@"windows"];
        if (windows.count > 0) {
            NSMutableArray *values = [NSMutableArray array];
            for (NSDictionary *window in windows) {
                NSString *label = [window[@"name"] isEqualToString:@"weekly"] ? @"Semanal" : @"5h";
                [values addObject:[NSString stringWithFormat:@"%@ %@%%", label, window[@"used_percent"]]];
            }
            NSString *badge = self.statuses[provider] ?: @"Indisponível";
            return [NSString stringWithFormat:@"Antigravity · %@ · %@", [values componentsJoinedByString:@" · "], badge];
        }
    }
    NSString *raw = self.statuses[provider] ?: @"--";
    return [NSString stringWithFormat:@"%@ · %@", [self displayNameForProvider:provider], raw];
}

- (NSString *)shortPercentageForStatus:(NSString *)status {
    if (!status || [status isEqualToString:@"--"] || [status isEqualToString:@"Desativado"]) {
        return @"--";
    }

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d+%(\\s*sem)?)" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:status options:0 range:NSMakeRange(0, status.length)];
    if (match && match.numberOfRanges > 1) {
        return [status substringWithRange:[match rangeAtIndex:1]];
    }

    if ([status containsString:@"Offline"]) return @"Offline";
    if ([status containsString:@"Ativo"]) return @"Ativo";
    if ([status containsString:@"Pronto"]) return @"Pronto";

    return [status componentsSeparatedByString:@" "].firstObject ?: status;
}

- (NSString *)providerForIdentifier:(NSTouchBarItemIdentifier)identifier {
    if ([identifier isEqualToString:kCodexItem]) return @"codex";
    if ([identifier isEqualToString:kClaudeItem]) return @"claude";
    if ([identifier isEqualToString:kAntigravityItem]) return @"antigravity";
    if ([identifier isEqualToString:kGeminiItem]) return @"gemini";
    if ([identifier isEqualToString:kDeepseekItem]) return @"deepseek";
    if ([identifier isEqualToString:kOllamaItem]) return @"ollama";
    if ([identifier isEqualToString:kPerplexityItem]) return @"perplexity";
    return nil;
}

- (NSImage *)iconForProvider:(NSString *)provider {
    NSURL *assetsURL = [[NSBundle mainBundle].resourceURL URLByAppendingPathComponent:@"assets"];
    NSString *filename = [NSString stringWithFormat:@"%@.png", provider];
    NSURL *fileURL = [assetsURL URLByAppendingPathComponent:filename];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        fileURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"assets/%@", filename]];
    }
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:fileURL];
    if (image) {
        image.size = NSMakeSize(18, 18);
    }
    return image;
}

- (NSImage *)largeIconForProvider:(NSString *)provider {
    NSURL *assetsURL = [[NSBundle mainBundle].resourceURL URLByAppendingPathComponent:@"assets"];
    NSString *filename = [NSString stringWithFormat:@"%@.png", provider];
    NSURL *fileURL = [assetsURL URLByAppendingPathComponent:filename];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        fileURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"assets/%@", filename]];
    }
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:fileURL];
    if (image) {
        image.size = NSMakeSize(32, 32);
    }
    return image;
}

- (void)openProviderWithIdentifier:(NSString *)provider {
    if ([provider isEqualToString:@"antigravity"]) {
        NSURL *appURL = [NSURL fileURLWithPath:@"/Applications/Antigravity.app"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:appURL.path]) {
            [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                                  configuration:[NSWorkspaceOpenConfiguration configuration]
                                              completionHandler:nil];
        }
    } else if ([provider isEqualToString:@"claude"]) {
        NSURL *appURL = [NSURL fileURLWithPath:@"/Applications/Claude.app"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:appURL.path]) {
            [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                                  configuration:[NSWorkspaceOpenConfiguration configuration]
                                              completionHandler:nil];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://claude.ai"]];
        }
    } else if ([provider isEqualToString:@"codex"]) {
        NSURL *appURL = [NSURL fileURLWithPath:@"/Applications/ChatGPT.app"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:appURL.path]) {
            [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                                  configuration:[NSWorkspaceOpenConfiguration configuration]
                                              completionHandler:nil];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://chatgpt.com"]];
        }
    } else if ([provider isEqualToString:@"gemini"]) {
        NSURL *appURL = [NSURL fileURLWithPath:@"/Applications/Gemini.app"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:appURL.path]) {
            [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                                  configuration:[NSWorkspaceOpenConfiguration configuration]
                                              completionHandler:nil];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://gemini.google.com"]];
        }
    } else if ([provider isEqualToString:@"deepseek"]) {
        NSURL *appURL = [NSURL fileURLWithPath:@"/Applications/DeepSeek.app"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:appURL.path]) {
            [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                                  configuration:[NSWorkspaceOpenConfiguration configuration]
                                              completionHandler:nil];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://chat.deepseek.com"]];
        }
    } else if ([provider isEqualToString:@"ollama"]) {
        NSURL *appURL = [NSURL fileURLWithPath:@"/Applications/Ollama.app"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:appURL.path]) {
            [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                                  configuration:[NSWorkspaceOpenConfiguration configuration]
                                              completionHandler:nil];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://localhost:11434"]];
        }
    } else if ([provider isEqualToString:@"perplexity"]) {
        NSURL *appURL = [NSURL fileURLWithPath:@"/Applications/Perplexity.app"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:appURL.path]) {
            [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                                  configuration:[NSWorkspaceOpenConfiguration configuration]
                                              completionHandler:nil];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.perplexity.ai"]];
        }
    }
    [self dismissTouchBar];
}

#pragma mark - Teclado Virtual ESC e Controles de Hardware do macOS

static BOOL CTBDefaultOutputDevice(AudioDeviceID *device) {
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    UInt32 size = sizeof(*device);
    *device = kAudioObjectUnknown;
    return AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL,
                                      &size, device) == noErr && *device != kAudioObjectUnknown;
}

static AudioObjectPropertyAddress CTBAudioAddress(AudioObjectPropertySelector selector, UInt32 channel) {
    AudioObjectPropertyAddress address = {
        selector, kAudioDevicePropertyScopeOutput, channel
    };
    return address;
}

static BOOL CTBReadVolumeAtChannel(AudioDeviceID device, UInt32 channel, Float32 *value) {
    AudioObjectPropertyAddress address = CTBAudioAddress(kAudioDevicePropertyVolumeScalar, channel);
    UInt32 size = sizeof(*value);
    return AudioObjectGetPropertyData(device, &address, 0, NULL, &size, value) == noErr;
}

static BOOL CTBAudioPropertyWritable(AudioDeviceID device, AudioObjectPropertySelector selector, UInt32 channel) {
    AudioObjectPropertyAddress address = CTBAudioAddress(selector, channel);
    Boolean writable = false;
    return AudioObjectIsPropertySettable(device, &address, &writable) == noErr && writable;
}

static BOOL CTBWriteVolumeAtChannel(AudioDeviceID device, UInt32 channel, Float32 value) {
    AudioObjectPropertyAddress address = CTBAudioAddress(kAudioDevicePropertyVolumeScalar, channel);
    if (!CTBAudioPropertyWritable(device, kAudioDevicePropertyVolumeScalar, channel)) return NO;
    return AudioObjectSetPropertyData(device, &address, 0, NULL,
                                      sizeof(value), &value) == noErr;
}

static BOOL CTBReadOutputVolume(AudioDeviceID device, Float32 *volume) {
    if (CTBReadVolumeAtChannel(device, kAudioObjectPropertyElementMain, volume)) return YES;
    Float32 left = 0, right = 0;
    BOOL hasLeft = CTBReadVolumeAtChannel(device, 1, &left);
    BOOL hasRight = CTBReadVolumeAtChannel(device, 2, &right);
    if (!hasLeft && !hasRight) return NO;
    *volume = hasLeft && hasRight ? fmaxf(left, right) : (hasLeft ? left : right);
    return YES;
}

static BOOL CTBWriteOutputVolume(AudioDeviceID device, Float32 target) {
    target = fmaxf(0.0f, fminf(1.0f, target));
    if (CTBWriteVolumeAtChannel(device, kAudioObjectPropertyElementMain, target)) return YES;

    Float32 left = 0, right = 0;
    BOOL hasLeft = CTBReadVolumeAtChannel(device, 1, &left);
    BOOL hasRight = CTBReadVolumeAtChannel(device, 2, &right);
    if (!hasLeft && !hasRight) return NO;

    Float32 peak = fmaxf(hasLeft ? left : 0, hasRight ? right : 0);
    Float32 leftTarget = peak > 0 ? target * left / peak : target;
    Float32 rightTarget = peak > 0 ? target * right / peak : target;
    BOOL leftChanged = !hasLeft || CTBWriteVolumeAtChannel(device, 1, leftTarget);
    BOOL rightChanged = !hasRight || CTBWriteVolumeAtChannel(device, 2, rightTarget);
    return leftChanged && rightChanged;
}

static BOOL CTBReadOutputMute(AudioDeviceID device, UInt32 *muted) {
    AudioObjectPropertyAddress address = CTBAudioAddress(kAudioDevicePropertyMute,
                                                          kAudioObjectPropertyElementMain);
    UInt32 size = sizeof(*muted);
    return AudioObjectGetPropertyData(device, &address, 0, NULL, &size, muted) == noErr;
}

static BOOL CTBWriteOutputMute(AudioDeviceID device, UInt32 muted) {
    AudioObjectPropertyAddress address = CTBAudioAddress(kAudioDevicePropertyMute,
                                                          kAudioObjectPropertyElementMain);
    if (!CTBAudioPropertyWritable(device, kAudioDevicePropertyMute,
                                  kAudioObjectPropertyElementMain)) return NO;
    return AudioObjectSetPropertyData(device, &address, 0, NULL,
                                      sizeof(muted), &muted) == noErr;
}

static BOOL CTBAdjustOutputVolume(AudioDeviceID device, Float32 delta) {
    Float32 current = 0;
    if (!CTBReadOutputVolume(device, &current)) return NO;
    Float32 target = fmaxf(0.0f, fminf(1.0f, current + delta));
    if (!CTBWriteOutputVolume(device, target)) return NO;
    if (target > 0) CTBWriteOutputMute(device, 0);
    return YES;
}

typedef int (*CTBDisplayGetBrightness)(CGDirectDisplayID display, float *brightness);
typedef int (*CTBDisplaySetBrightness)(CGDirectDisplayID display, float brightness);
static CTBDisplayGetBrightness gDisplayGetBrightness = NULL;
static CTBDisplaySetBrightness gDisplaySetBrightness = NULL;

static void CTBInitDisplayBrightness(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY);
        if (framework) {
            gDisplayGetBrightness = (CTBDisplayGetBrightness)dlsym(framework, "DisplayServicesGetBrightness");
            gDisplaySetBrightness = (CTBDisplaySetBrightness)dlsym(framework, "DisplayServicesSetBrightness");
        }
    });
}

static BOOL CTBAdjustDisplayBrightness(float delta) {
    CTBInitDisplayBrightness();
    CGDirectDisplayID display = CGMainDisplayID();
    if (!display || !gDisplayGetBrightness || !gDisplaySetBrightness) return NO;
    float current = 0;
    if (gDisplayGetBrightness(display, &current) != 0) return NO;
    float target = fmaxf(0.0f, fminf(1.0f, current + delta));
    return gDisplaySetBrightness(display, target) == 0;
}

typedef Boolean (*MRMediaRemoteSendCommandFunc)(unsigned int command, id options);
static MRMediaRemoteSendCommandFunc gMRSendCommand = NULL;

static void InitMediaRemote(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
        if (handle) {
            gMRSendCommand = (MRMediaRemoteSendCommandFunc)dlsym(handle, "MRMediaRemoteSendCommand");
        }
    });
}

- (void)runAppleScriptAsync:(NSString *)source {
    if (!source) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
        [script executeAndReturnError:nil];
    });
}

- (void)handleEscTap {
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventRef keyDown = CGEventCreateKeyboardEvent(src, (CGKeyCode)53, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(src, (CGKeyCode)53, false);
    CGEventPost(kCGHIDEventTap, keyDown);
    CGEventPost(kCGHIDEventTap, keyUp);
    CGEventPost(kCGSessionEventTap, keyDown);
    CGEventPost(kCGSessionEventTap, keyUp);
    if (keyDown) CFRelease(keyDown);
    if (keyUp) CFRelease(keyUp);
    if (src) CFRelease(src);

    [self runAppleScriptAsync:@"tell application \"System Events\" to key code 53"];
}

- (void)postSystemKey:(int)keyType {
    NSEvent *eventDown = [NSEvent otherEventWithType:NSEventTypeSystemDefined
                                            location:NSZeroPoint
                                       modifierFlags:0xa00
                                           timestamp:0
                                        windowNumber:0
                                             context:nil
                                             subtype:8
                                               data1:(keyType << 16) | (0xa << 8)
                                               data2:-1];
    CGEventPost(kCGHIDEventTap, [eventDown CGEvent]);

    NSEvent *eventUp = [NSEvent otherEventWithType:NSEventTypeSystemDefined
                                          location:NSZeroPoint
                                     modifierFlags:0xb00
                                         timestamp:0
                                      windowNumber:0
                                           context:nil
                                           subtype:8
                                             data1:(keyType << 16) | (0xb << 8)
                                             data2:-1];
    CGEventPost(kCGHIDEventTap, [eventUp CGEvent]);
}

- (void)handleBrightnessDown {
    if (!CTBAdjustDisplayBrightness(-0.0625f)) {
        NSLog(@"CodeTouchBar: brilho não é ajustável no monitor principal; tentando tecla do sistema.");
        [self postSystemKey:NX_KEYTYPE_BRIGHTNESS_DOWN];
    }
}

- (void)handleBrightnessUp {
    if (!CTBAdjustDisplayBrightness(0.0625f)) {
        NSLog(@"CodeTouchBar: brilho não é ajustável no monitor principal; tentando tecla do sistema.");
        [self postSystemKey:NX_KEYTYPE_BRIGHTNESS_UP];
    }
}

- (void)handleMediaPrev {
    InitMediaRemote();
    if (gMRSendCommand) {
        gMRSendCommand(5, nil); // 5 = kMRPreviousTrack
    }
    [[CodeTouchBarHUDController sharedHUD] showMediaHUDWithAction:@"Faixa Anterior" iconName:@"backward.fill" subtitle:@"Controle de Mídia"];
    [self runAppleScriptAsync:
        @"tell application \"System Events\"\n"
        @"  set pList to name of every application process\n"
        @"end tell\n"
        @"if pList contains \"Spotify\" then\n"
        @"  tell application \"Spotify\" to previous track\n"
        @"else if pList contains \"Music\" then\n"
        @"  tell application \"Music\" to previous track\n"
        @"end if"
    ];
    [self postSystemKey:NX_KEYTYPE_PREVIOUS];
}

- (void)handleMediaPlayPause {
    InitMediaRemote();
    if (gMRSendCommand) {
        gMRSendCommand(2, nil); // 2 = kMRTogglePlayPause
    }
    [[CodeTouchBarHUDController sharedHUD] showMediaHUDWithAction:@"Reproduzir / Pausar" iconName:@"playpause.fill" subtitle:@"Controle de Mídia"];
    [self runAppleScriptAsync:
        @"tell application \"System Events\"\n"
        @"  set pList to name of every application process\n"
        @"end tell\n"
        @"if pList contains \"Spotify\" then\n"
        @"  tell application \"Spotify\" to playpause\n"
        @"else if pList contains \"Music\" then\n"
        @"  tell application \"Music\" to playpause\n"
        @"end if"
    ];
    [self postSystemKey:NX_KEYTYPE_PLAY];
}

- (void)handleMediaNext {
    InitMediaRemote();
    if (gMRSendCommand) {
        gMRSendCommand(4, nil); // 4 = kMRNextTrack
    }
    [[CodeTouchBarHUDController sharedHUD] showMediaHUDWithAction:@"Próxima Faixa" iconName:@"forward.fill" subtitle:@"Controle de Mídia"];
    [self runAppleScriptAsync:
        @"tell application \"System Events\"\n"
        @"  set pList to name of every application process\n"
        @"end tell\n"
        @"if pList contains \"Spotify\" then\n"
        @"  tell application \"Spotify\" to next track\n"
        @"else if pList contains \"Music\" then\n"
        @"  tell application \"Music\" to next track\n"
        @"end if"
    ];
    [self postSystemKey:NX_KEYTYPE_NEXT];
}

- (void)handleVolumeMute {
    dispatch_async(self.audioControlQueue, ^{
        AudioDeviceID device;
        UInt32 muted = 0;
        if (!CTBDefaultOutputDevice(&device) || !CTBReadOutputMute(device, &muted) ||
            !CTBWriteOutputMute(device, muted ? 0 : 1)) {
            NSLog(@"CodeTouchBar: mute não é ajustável na saída de áudio atual; tentando tecla do sistema.");
            dispatch_async(dispatch_get_main_queue(), ^{ [self postSystemKey:NX_KEYTYPE_MUTE]; });
        }
    });
}

- (void)adjustVolumeBy:(Float32)delta {
    dispatch_async(self.audioControlQueue, ^{
        AudioDeviceID device;
        if (!CTBDefaultOutputDevice(&device) || !CTBAdjustOutputVolume(device, delta)) {
            NSLog(@"CodeTouchBar: não foi possível ajustar o volume da saída atual.");
        }
    });
}

- (void)handleVolumeDown {
    [self adjustVolumeBy:-0.06f];
}

- (void)handleVolumeUp {
    [self adjustVolumeBy:0.06f];
}

- (void)showControlsMode {
    self.showSystemControls = YES;
    self.activeDetailProvider = nil;
    if (self.isModalTouchBarPresented && self.modalTouchBar) {
        self.modalTouchBar.defaultItemIdentifiers = [self identifiersForCurrentStateWithClose:YES];
    }
    [self updateAppTouchBar];
}

- (void)hideControlsMode {
    self.showSystemControls = NO;
    self.activeDetailProvider = nil;
    if (self.isModalTouchBarPresented && self.modalTouchBar) {
        self.modalTouchBar.defaultItemIdentifiers = [self identifiersForCurrentStateWithClose:YES];
    }
    [self updateAppTouchBar];
}

#pragma mark - Menu Bar (Persistente e Estável)

- (void)buildMenuBarItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.visible = YES;
    self.statusItem.behavior = 0; // Previne remoção acidental

    NSImage *sparkles = [NSImage imageWithSystemSymbolName:@"sparkles" accessibilityDescription:@"CodeTouchBar"];
    self.statusItem.button.image = sparkles;
    self.statusItem.button.title = @"";
    self.statusItem.button.toolTip = @"CodeTouchBar Studio — Assistentes de IA";

    self.statusMenu = [[NSMenu alloc] initWithTitle:@"CodeTouchBar"];
    self.statusMenu.delegate = self;
    self.statusItem.menu = self.statusMenu;

    [self updateMenuBarMenu];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == self.statusMenu) {
        [self updateMenuBarMenu];
    }
}

- (void)updateMenuBarMenu {
    NSMenu *menu = self.statusMenu ?: [[NSMenu alloc] initWithTitle:@"CodeTouchBar"];
    [menu removeAllItems];

    NSMenuItem *header = [[NSMenuItem alloc] initWithTitle:@"CodeTouchBar Studio" action:nil keyEquivalent:@""];
    header.attributedTitle = [[NSAttributedString alloc] initWithString:@"CodeTouchBar Studio"
                                                             attributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:13]}];
    [menu addItem:header];
    [menu addItem:NSMenuItem.separatorItem];

    for (NSString *pid in [self allProviders]) {
        if (![self providerEnabled:pid]) continue;

        NSString *rawStatus = self.statuses[pid] ?: @"--";
        NSString *title = [NSString stringWithFormat:@"%@: %@", [self displayNameForProvider:pid], rawStatus];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(menuOpenProvider:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = pid;

        NSImage *icon = [self iconForProvider:pid];
        if (icon) {
            NSImage *menuIcon = [icon copy];
            menuIcon.size = NSMakeSize(16, 16);
            item.image = menuIcon;
        }
        [menu addItem:item];
    }

    if (self.lastRefreshDate) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"HH:mm:ss";
        NSString *timeStr = [NSString stringWithFormat:@"Última sincronização: %@", [df stringFromDate:self.lastRefreshDate]];
        NSMenuItem *timeItem = [[NSMenuItem alloc] initWithTitle:timeStr action:nil keyEquivalent:@""];
        timeItem.enabled = NO;
        [menu addItem:timeItem];
    }

    [menu addItem:NSMenuItem.separatorItem];

    BOOL isWindowVisible = self.controlWindow.isVisible;
    NSString *windowActionTitle = isWindowVisible ? @"Ocultar Painel de Controle" : @"Abrir Painel de Controle";
    SEL windowAction = isWindowVisible ? @selector(hideControlWindow) : @selector(showControlWindow);
    NSMenuItem *windowItem = [menu addItemWithTitle:windowActionTitle action:windowAction keyEquivalent:@"o"];
    windowItem.target = self;

    NSMenuItem *tbItem = [menu addItemWithTitle:@"Mostrar na Touch Bar" action:@selector(showTouchBar) keyEquivalent:@"t"];
    tbItem.target = self;

    NSMenuItem *controlsItem = [menu addItemWithTitle:@"Controles do Sistema na Touch Bar" action:@selector(showControlsMode) keyEquivalent:@"c"];
    controlsItem.target = self;

    NSMenuItem *refreshItem = [menu addItemWithTitle:@"Atualizar métricas agora" action:@selector(refreshStatuses) keyEquivalent:@"r"];
    refreshItem.target = self;

    NSMenuItem *prefItem = [menu addItemWithTitle:@"Preferências…" action:@selector(showPreferences) keyEquivalent:@","];
    prefItem.target = self;

    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *quitItem = [menu addItemWithTitle:@"Sair do CodeTouchBar" action:@selector(quit) keyEquivalent:@"q"];
    quitItem.target = self;
}

- (void)menuOpenProvider:(NSMenuItem *)sender {
    NSString *pid = sender.representedObject;
    if (pid.length > 0) {
        [self openProviderWithIdentifier:pid];
    }
}

- (void)hideControlWindow {
    [self.controlWindow orderOut:nil];
    [self updateMenuBarMenu];
}

#pragma mark - Janela de Controle

- (void)showControlWindow {
    if (!self.controlWindow) {
        NSRect frame = NSMakeRect(0, 0, 520, 520);
        self.controlWindow = [[NSWindow alloc] initWithContentRect:frame
                                                         styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                           backing:NSBackingStoreBuffered
                                                             defer:NO];
        self.controlWindow.title = @"CodeTouchBar Studio";
        self.controlWindow.delegate = self;
        [self.controlWindow setReleasedWhenClosed:NO];

        NSView *content = self.controlWindow.contentView;

        NSTextField *title = [NSTextField labelWithString:@"CodeTouchBar Studio"];
        title.font = [NSFont boldSystemFontOfSize:18];
        title.frame = NSMakeRect(24, 478, 280, 26);
        [content addSubview:title];

        NSTextField *subtitle = [NSTextField labelWithString:@"Painel de controle e monitoramento na Touch Bar"];
        subtitle.font = [NSFont systemFontOfSize:12];
        subtitle.textColor = [NSColor secondaryLabelColor];
        subtitle.frame = NSMakeRect(24, 458, 320, 18);
        [content addSubview:subtitle];

        NSTextField *statusBadge = [NSTextField labelWithString:@"🟢 Ativo na Barra de Menus"];
        statusBadge.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
        statusBadge.textColor = [NSColor secondaryLabelColor];
        statusBadge.alignment = NSTextAlignmentRight;
        statusBadge.frame = NSMakeRect(320, 478, 176, 20);
        [content addSubview:statusBadge];

        self.controlWindowValueLabels = [NSMutableDictionary dictionary];
        self.controlWindowOpenButtons = [NSMutableDictionary dictionary];

        NSArray *providers = [self allProviders];
        CGFloat cardH = 56;
        CGFloat spacing = 8;
        CGFloat totalDocH = providers.count * (cardH + spacing) + 8;

        NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 50, 480, 396)];
        scrollView.hasVerticalScroller = YES;
        scrollView.autohidesScrollers = YES;
        scrollView.borderType = NSNoBorder;
        scrollView.drawsBackground = NO;

        NSView *docView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 464, totalDocH)];

        for (NSUInteger i = 0; i < providers.count; i++) {
            NSString *pid = providers[i];
            CGFloat y = totalDocH - (i + 1) * (cardH + spacing);

            NSBox *card = [[NSBox alloc] initWithFrame:NSMakeRect(0, y, 464, cardH)];
            card.boxType = NSBoxCustom;
            card.cornerRadius = 8;
            card.borderWidth = 1;
            card.borderColor = [NSColor separatorColor];
            card.fillColor = [NSColor controlBackgroundColor];

            NSImage *icon = [self largeIconForProvider:pid];
            if (icon) {
                NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(12, 12, 32, 32)];
                iv.image = icon;
                [card addSubview:iv];
            }

            NSTextField *nameLabel = [NSTextField labelWithString:[self displayNameForProvider:pid]];
            nameLabel.font = [NSFont boldSystemFontOfSize:13];
            nameLabel.frame = NSMakeRect(52, 28, 160, 20);
            [card addSubview:nameLabel];

            NSTextField *subLabel = [NSTextField labelWithString:[self subtitleForProvider:pid]];
            subLabel.font = [NSFont systemFontOfSize:11];
            subLabel.textColor = [NSColor secondaryLabelColor];
            subLabel.frame = NSMakeRect(52, 10, 180, 16);
            [card addSubview:subLabel];

            NSTextField *valLabel = [NSTextField labelWithString:self.statuses[pid] ?: @"--"];
            valLabel.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightSemibold];
            valLabel.alignment = NSTextAlignmentRight;
            valLabel.frame = NSMakeRect(220, 16, 150, 22);
            self.controlWindowValueLabels[pid] = valLabel;
            [card addSubview:valLabel];

            NSButton *openBtn = [NSButton buttonWithTitle:@"Abrir" target:self action:@selector(controlWindowOpenProvider:)];
            openBtn.frame = NSMakeRect(380, 12, 72, 30);
            openBtn.identifier = pid;
            self.controlWindowOpenButtons[pid] = openBtn;
            [card addSubview:openBtn];

            [docView addSubview:card];
        }

        scrollView.documentView = docView;
        [content addSubview:scrollView];

        self.controlWindowLastSyncLabel = [NSTextField labelWithString:@"Última sincronização: aguardando…"];
        self.controlWindowLastSyncLabel.font = [NSFont systemFontOfSize:11];
        self.controlWindowLastSyncLabel.textColor = [NSColor tertiaryLabelColor];
        self.controlWindowLastSyncLabel.frame = NSMakeRect(24, 34, 250, 16);
        [content addSubview:self.controlWindowLastSyncLabel];

        NSButton *preferencesButton = [NSButton buttonWithTitle:@"Preferências…" target:self action:@selector(showPreferences)];
        preferencesButton.frame = NSMakeRect(20, 8, 120, 28);
        [content addSubview:preferencesButton];

        NSButton *refreshBtn = [NSButton buttonWithTitle:@"Atualizar agora" target:self action:@selector(refreshStatuses)];
        refreshBtn.frame = NSMakeRect(160, 8, 130, 28);
        [content addSubview:refreshBtn];

        NSButton *touchBarButton = [NSButton buttonWithTitle:@"Mostrar na Touch Bar" target:self action:@selector(showTouchBar)];
        touchBarButton.frame = NSMakeRect(300, 8, 198, 28);
        [content addSubview:touchBarButton];
    }

    [self updateControlWindow];
    [self updateAppTouchBar];
    [NSApp activateIgnoringOtherApps:YES];
    [self.controlWindow center];
    [self.controlWindow makeKeyAndOrderFront:nil];
    [self updateMenuBarMenu];
}

- (void)updateControlWindow {
    if (!self.controlWindow) return;
    for (NSString *pid in [self allProviders]) {
        NSTextField *valLabel = self.controlWindowValueLabels[pid];
        NSButton *openBtn = self.controlWindowOpenButtons[pid];
        BOOL enabled = [self providerEnabled:pid];
        if (!enabled) {
            valLabel.stringValue = @"Desativado";
            valLabel.textColor = [NSColor tertiaryLabelColor];
            openBtn.enabled = NO;
        } else {
            NSString *val = self.statuses[pid] ?: @"--";
            valLabel.stringValue = val;
            valLabel.textColor = [NSColor labelColor];
            openBtn.enabled = YES;
        }
    }
    if (self.lastRefreshDate && self.controlWindowLastSyncLabel) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"HH:mm:ss";
        self.controlWindowLastSyncLabel.stringValue = [NSString stringWithFormat:@"Última sincronização: %@", [df stringFromDate:self.lastRefreshDate]];
    }
}

- (void)controlWindowOpenProvider:(NSButton *)sender {
    NSString *pid = sender.identifier;
    if (pid.length > 0) {
        [self openProviderWithIdentifier:pid];
    }
}

#pragma mark - Touch Bar Integration (ESC + Ícones com Percentual + Detalhes + Controles)

- (void)registerTouchBarEntry {
    NSString *frameworkPath = @"/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation";
    void *framework = dlopen(frameworkPath.UTF8String, RTLD_NOW);
    SEL addSelector = NSSelectorFromString(@"addSystemTrayItem:");
    Method addMethod = class_getClassMethod(NSTouchBarItem.class, addSelector);
    void *presenceSymbol = framework ? dlsym(framework, "DFRElementSetControlStripPresenceForIdentifier") : NULL;
    if (!framework || !addMethod || !presenceSymbol) {
        NSLog(@"CodeTouchBar: a API privada da Touch Bar não está disponível neste macOS.");
        return;
    }

    NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:kTrayIdentifier];
    NSImage *sparkles = [NSImage imageWithSystemSymbolName:@"sparkles" accessibilityDescription:@"AI"];
    NSButton *button = sparkles ? [NSButton buttonWithImage:sparkles target:self action:@selector(showTouchBar)]
                                : [NSButton buttonWithTitle:@"AI" target:self action:@selector(showTouchBar)];
    button.toolTip = @"Ver modelos de IA: Codex, Claude, Antigravity, Gemini, DeepSeek e mais";
    item.view = button;
    self.trayItem = item;
    self.trayButton = button;

    ((void (*)(id, SEL, id))objc_msgSend)(NSTouchBarItem.class, addSelector, item);
    typedef void (*PresenceFunction)(CFStringRef, Boolean);
    ((PresenceFunction)presenceSymbol)((__bridge CFStringRef)kTrayIdentifier, true);
}

- (NSArray<NSTouchBarItemIdentifier> *)identifiersForCurrentStateWithClose:(BOOL)includeClose {
    NSMutableArray<NSTouchBarItemIdentifier> *identifiers = [NSMutableArray array];

    // O ESC fica sempre na extrema esquerda da Touch Bar!
    [identifiers addObject:kEscItem];

    if (self.showSystemControls) {
        // MODO CONTROLES DO SISTEMA EXPANDIDO:
        // [esc] [◀ IAs] | [🔅] [🔆] | [⏮] [⏯] [⏭] | [🔇] [🔉] [🔊] | [↻] [Fechar]
        [identifiers addObject:kControlsBackItem];
        [identifiers addObject:kBrightnessDownItem];
        [identifiers addObject:kBrightnessUpItem];
        [identifiers addObject:NSTouchBarItemIdentifierFixedSpaceSmall];
        [identifiers addObject:kMediaPrevItem];
        [identifiers addObject:kMediaPlayPauseItem];
        [identifiers addObject:kMediaNextItem];
        [identifiers addObject:NSTouchBarItemIdentifierFixedSpaceSmall];
        [identifiers addObject:kVolumeMuteItem];
        [identifiers addObject:kVolumeDownItem];
        [identifiers addObject:kVolumeUpItem];
        [identifiers addObject:NSTouchBarItemIdentifierFlexibleSpace];
        [identifiers addObject:kRefreshItem];
        if (includeClose) [identifiers addObject:kCloseItem];
    } else if (self.activeDetailProvider.length > 0) {
        // MODO DETALHES DO MODELO SELECIONADO:
        // [esc] [◀ Voltar] [Ícone + Nome + Cota Completa + Reset] ... [Abrir App] [🎛️] [↻] [Fechar]
        [identifiers addObject:kBackItem];
        [identifiers addObject:kDetailInfoItem];
        [identifiers addObject:NSTouchBarItemIdentifierFlexibleSpace];
        [identifiers addObject:kOpenAppItem];
        [identifiers addObject:kControlsToggleItem];
        [identifiers addObject:kRefreshItem];
        if (includeClose) [identifiers addObject:kCloseItem];
    } else {
        // MODO PRINCIPAL: ESC + Ícones com Percentual dos modelos de LLM + Acesso a Controles
        NSDictionary<NSString *, NSString *> *itemIDs = @{
            @"codex": kCodexItem,
            @"claude": kClaudeItem,
            @"antigravity": kAntigravityItem,
            @"gemini": kGeminiItem,
            @"deepseek": kDeepseekItem,
            @"ollama": kOllamaItem,
            @"perplexity": kPerplexityItem
        };
        for (NSString *provider in [self allProviders]) {
            if ([self providerEnabled:provider]) {
                [identifiers addObject:itemIDs[provider]];
            }
        }
        [identifiers addObject:NSTouchBarItemIdentifierFlexibleSpace];
        [identifiers addObject:kControlsToggleItem];
        [identifiers addObject:kRefreshItem];
        if (includeClose) [identifiers addObject:kCloseItem];
    }
    return [identifiers copy];
}

- (NSTouchBar *)makeTouchBarWithCloseButton:(BOOL)includeClose {
    NSTouchBar *bar = [[NSTouchBar alloc] init];
    bar.delegate = self;
    bar.defaultItemIdentifiers = [self identifiersForCurrentStateWithClose:includeClose];
    bar.customizationIdentifier = @"com.codetouchbar.studio.usage-bar";
    bar.customizationAllowedItemIdentifiers = bar.defaultItemIdentifiers;
    return bar;
}

- (void)updateAppTouchBar {
    if (!self.touchBar) {
        self.touchBar = [self makeTouchBarWithCloseButton:NO];
    } else {
        self.touchBar.defaultItemIdentifiers = [self identifiersForCurrentStateWithClose:NO];
    }
    [NSApp setTouchBar:self.touchBar];
    if (self.controlWindow) {
        self.controlWindow.touchBar = self.touchBar;
    }
}

- (void)refreshStatusesIfStale {
    NSTimeInterval refreshInterval = [self.settings[@"refreshSeconds"] doubleValue];
    BOOL stale = !self.lastRefreshDate ||
                 [[NSDate date] timeIntervalSinceDate:self.lastRefreshDate] >= refreshInterval;
    if (stale) [self refreshStatuses];
}

- (void)updateTouchBarProviderButtons {
    for (NSString *provider in self.touchBarProviderButtons) {
        NSString *status = self.statuses[provider] ?: @"--";
        NSString *shortValue = [self shortPercentageForStatus:status];
        for (NSButton *button in self.touchBarProviderButtons[provider]) {
            button.title = shortValue;
            button.toolTip = [NSString stringWithFormat:@"%@: %@ (Toque para ver opções)",
                              [self displayNameForProvider:provider], status];
        }
    }

    NSString *provider = self.activeDetailProvider;
    if (provider.length > 0) {
        NSString *detail = [self detailDescriptionForProvider:provider];
        NSString *toolTip = [NSString stringWithFormat:@"Toque para abrir %@", [self appNameForProvider:provider]];
        for (NSButton *button in self.touchBarDetailInfoButtons) {
            button.title = detail;
            button.toolTip = toolTip;
        }
    }
}

- (void)showTouchBar {
    [self refreshStatusesIfStale];
    if (!self.modalTouchBar) {
        self.modalTouchBar = [self makeTouchBarWithCloseButton:YES];
    } else {
        self.modalTouchBar.defaultItemIdentifiers = [self identifiersForCurrentStateWithClose:YES];
    }

    if (!self.isModalTouchBarPresented) {
        SEL selector = NSSelectorFromString(@"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:");
        Method method = class_getClassMethod(NSTouchBar.class, selector);
        if (!method) {
            NSLog(@"CodeTouchBar: não foi possível abrir a faixa de métricas da Touch Bar.");
            return;
        }

        self.isModalTouchBarPresented = YES;
        typedef void (*PresentFunction)(id, SEL, id, int64_t, id);
        ((PresentFunction)objc_msgSend)(NSTouchBar.class, selector, self.modalTouchBar, 1, kTrayIdentifier);

        void *framework = dlopen(@"/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation".UTF8String, RTLD_NOW);
        void *closeBoxSymbol = framework ? dlsym(framework, "DFRSystemModalShowsCloseBoxWhenFrontMost") : NULL;
        if (closeBoxSymbol) {
            typedef void (*CloseBoxFunction)(Boolean);
            ((CloseBoxFunction)closeBoxSymbol)(true);
        }
    }
}

- (void)dismissTouchBar {
    self.showSystemControls = NO;
    self.activeDetailProvider = nil;
    self.isModalTouchBarPresented = NO;
    self.modalTouchBar = nil;
    SEL selector = NSSelectorFromString(@"dismissSystemModalTouchBar:");
    Method method = class_getClassMethod(NSTouchBar.class, selector);
    if (method) {
        NSTouchBar *dummy = [[NSTouchBar alloc] init];
        typedef void (*DismissFunction)(id, SEL, id);
        ((DismissFunction)objc_msgSend)(NSTouchBar.class, selector, dummy);
    }
}

- (void)backToMainTouchBar {
    self.showSystemControls = NO;
    self.activeDetailProvider = nil;
    if (self.isModalTouchBarPresented && self.modalTouchBar) {
        self.modalTouchBar.defaultItemIdentifiers = [self identifiersForCurrentStateWithClose:YES];
    }
    [self refreshStatusesIfStale];
    [self updateAppTouchBar];
}

- (void)openActiveProviderApp {
    if (self.activeDetailProvider.length > 0) {
        [self openProviderWithIdentifier:self.activeDetailProvider];
    }
}

- (void)touchBarModelIconClicked:(NSButton *)sender {
    NSString *provider = sender.identifier;
    if (provider.length > 0) {
        self.showSystemControls = NO;
        self.activeDetailProvider = provider;
        [self refreshStatusesIfStale];
        if (self.isModalTouchBarPresented && self.modalTouchBar) {
            self.modalTouchBar.defaultItemIdentifiers = [self identifiersForCurrentStateWithClose:YES];
        }
        [self updateAppTouchBar];
    }
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
    (void)touchBar;

    // Tecla ESC virtual
    if ([identifier isEqualToString:kEscItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSButton *btn = [NSButton buttonWithTitle:@"esc" target:self action:@selector(handleEscTap)];
        btn.font = [NSFont systemFontOfSize:14 weight:NSFontWeightRegular];
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kCloseItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:@"Fechar"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(dismissTouchBar)];
        btn.toolTip = @"Fechar Touch Bar";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kBackItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:@"Voltar"];
        if (!img) img = [NSImage imageNamed:NSImageNameTouchBarGoBackTemplate];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(backToMainTouchBar)];
        btn.toolTip = @"Voltar aos Modelos";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kControlsBackItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:@"Voltar"];
        if (!img) img = [NSImage imageNamed:NSImageNameTouchBarGoBackTemplate];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(hideControlsMode)];
        btn.toolTip = @"Voltar aos Modelos";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kControlsToggleItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageWithSystemSymbolName:@"slider.horizontal.3" accessibilityDescription:@"Controles"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(showControlsMode)];
        btn.toolTip = @"Controles do Sistema (Brilho, Volume e Mídia)";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kBrightnessDownItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageWithSystemSymbolName:@"sun.min" accessibilityDescription:@"Diminuir Brilho"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(handleBrightnessDown)];
        btn.toolTip = @"Diminuir Brilho";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kBrightnessUpItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageWithSystemSymbolName:@"sun.max" accessibilityDescription:@"Aumentar Brilho"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(handleBrightnessUp)];
        btn.toolTip = @"Aumentar Brilho";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kMediaPrevItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageNamed:NSImageNameTouchBarSkipBackTemplate];
        if (!img) img = [NSImage imageWithSystemSymbolName:@"backward.fill" accessibilityDescription:@"Faixa Anterior"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(handleMediaPrev)];
        btn.toolTip = @"Faixa Anterior";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kMediaPlayPauseItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageNamed:NSImageNameTouchBarPlayPauseTemplate];
        if (!img) img = [NSImage imageWithSystemSymbolName:@"playpause.fill" accessibilityDescription:@"Reproduzir / Pausar"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(handleMediaPlayPause)];
        btn.toolTip = @"Reproduzir / Pausar";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kMediaNextItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageNamed:NSImageNameTouchBarSkipAheadTemplate];
        if (!img) img = [NSImage imageWithSystemSymbolName:@"forward.fill" accessibilityDescription:@"Próxima Faixa"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(handleMediaNext)];
        btn.toolTip = @"Próxima Faixa";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kVolumeMuteItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageNamed:NSImageNameTouchBarAudioOutputMuteTemplate];
        if (!img) img = [NSImage imageWithSystemSymbolName:@"speaker.slash.fill" accessibilityDescription:@"Mudo"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(handleVolumeMute)];
        btn.toolTip = @"Mudo";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kVolumeDownItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageNamed:NSImageNameTouchBarAudioOutputVolumeLowTemplate];
        if (!img) img = [NSImage imageWithSystemSymbolName:@"speaker.wave.1.fill" accessibilityDescription:@"Diminuir Volume"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(handleVolumeDown)];
        btn.toolTip = @"Diminuir Volume";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kVolumeUpItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *img = [NSImage imageNamed:NSImageNameTouchBarAudioOutputVolumeHighTemplate];
        if (!img) img = [NSImage imageWithSystemSymbolName:@"speaker.wave.3.fill" accessibilityDescription:@"Aumentar Volume"];
        NSButton *btn = [NSButton buttonWithImage:img target:self action:@selector(handleVolumeUp)];
        btn.toolTip = @"Aumentar Volume";
        item.view = btn;
        return item;
    }

    if ([identifier isEqualToString:kRefreshItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *refreshImg = [NSImage imageNamed:NSImageNameTouchBarRefreshTemplate];
        if (!refreshImg) refreshImg = [NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:@"Atualizar"];
        NSButton *button = [NSButton buttonWithImage:refreshImg target:self action:@selector(refreshStatuses)];
        button.toolTip = @"Atualizar métricas agora";
        item.view = button;
        return item;
    }

    // Item de Detalhes expandido do modelo ativo
    if ([identifier isEqualToString:kDetailInfoItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSString *pid = self.activeDetailProvider;
        NSString *detailText = [self detailDescriptionForProvider:pid];
        NSImage *icon = [self iconForProvider:pid];

        NSButton *btn = [NSButton buttonWithTitle:detailText target:self action:@selector(openActiveProviderApp)];
        if (icon) {
            btn.image = icon;
            btn.imagePosition = NSImageLeading;
            btn.imageHugsTitle = YES;
        }
        btn.toolTip = [NSString stringWithFormat:@"Toque para abrir %@", [self appNameForProvider:pid]];
        [self.touchBarDetailInfoButtons addObject:btn];
        item.view = btn;
        return item;
    }

    // Botão de ação rápida na tela de detalhes
    if ([identifier isEqualToString:kOpenAppItem]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSString *pid = self.activeDetailProvider;
        NSString *btnTitle = [NSString stringWithFormat:@"Abrir %@", [self appNameForProvider:pid]];
        NSButton *btn = [NSButton buttonWithTitle:btnTitle target:self action:@selector(openActiveProviderApp)];
        btn.bezelColor = [NSColor systemBlueColor];
        item.view = btn;
        return item;
    }

    // Modo Principal: ÍCONE + PERCENTUAL DO MODELO DE LLM
    NSString *provider = [self providerForIdentifier:identifier];
    if (provider) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *icon = [self iconForProvider:provider];
        NSString *status = self.statuses[provider] ?: @"--";
        NSString *shortPct = [self shortPercentageForStatus:status];

        NSButton *button = [NSButton buttonWithTitle:shortPct target:self action:@selector(touchBarModelIconClicked:)];
        button.image = icon;
        button.imagePosition = NSImageLeading;
        button.imageHugsTitle = YES;
        button.identifier = provider;
        button.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium];
        button.toolTip = [NSString stringWithFormat:@"%@: %@ (Toque para ver opções)", [self displayNameForProvider:provider], status];
        NSHashTable<NSButton *> *buttons = self.touchBarProviderButtons[provider];
        if (!buttons) {
            buttons = [NSHashTable weakObjectsHashTable];
            self.touchBarProviderButtons[provider] = buttons;
        }
        [buttons addObject:button];
        item.view = button;
        return item;
    }

    return nil;
}

#pragma mark - Notificações de Limites

- (void)checkLimitsAndNotify {
    if (![self.settings[@"notificationsEnabled"] boolValue]) return;

    NSInteger critThresh = [self.settings[@"criticalThreshold"] integerValue] ?: 90;
    NSInteger warnThresh = [self.settings[@"warningThreshold"] integerValue] ?: 75;

    for (NSString *provider in [self allProviders]) {
        if (![self providerEnabled:provider]) continue;

        NSString *status = self.statuses[provider];
        if (!status || status.length == 0) continue;
        NSDictionary *metric = self.providerMetrics[provider];
        if (![metric[@"kind"] isEqualToString:@"quota"] || ![metric[@"state"] isEqualToString:@"available"]) continue;

        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(\\d+)%" options:0 error:nil];
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:status options:0 range:NSMakeRange(0, status.length)];
        if (matches.count == 0) continue;

        // Claude can show both session and weekly usage. Alert against the highest
        // percentage so the first (lower) window does not hide an exhausted quota.
        NSInteger pct = 0;
        for (NSTextCheckingResult *match in matches) {
            if (match.numberOfRanges > 1) {
                NSString *numStr = [status substringWithRange:[match rangeAtIndex:1]];
                pct = MAX(pct, numStr.integerValue);
            }
        }

        NSString *previousLevel = self.notifiedProviders[provider];
        if (pct >= critThresh) {
            if (![previousLevel isEqualToString:@"critical"]) {
                self.notifiedProviders[provider] = @"critical";
                [self sendNotificationForProvider:provider percentage:pct message:status isCritical:YES];
            }
        } else if (pct >= warnThresh) {
            if (!previousLevel) {
                self.notifiedProviders[provider] = @"warning";
                [self sendNotificationForProvider:provider percentage:pct message:status isCritical:NO];
            }
        } else {
            [self.notifiedProviders removeObjectForKey:provider];
        }
    }
}

- (void)sendNotificationForProvider:(NSString *)provider percentage:(NSInteger)pct message:(NSString *)msg isCritical:(BOOL)isCritical {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = [NSString stringWithFormat:@"%@ — Limite %@", [self displayNameForProvider:provider], isCritical ? @"Crítico" : @"Aviso"];
    notification.informativeText = [NSString stringWithFormat:@"O uso atingiu %ld%% (%@). Verifique sua cota para evitar interrupções.", (long)pct, msg];
    notification.soundName = NSUserNotificationDefaultSoundName;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
#pragma clang diagnostic pop
}

#pragma mark - Persistência no Início de Sessão (LaunchAgent)

- (void)setLaunchAtLoginEnabled:(BOOL)enabled {
    NSString *agentDir = [@"~/Library/LaunchAgents" stringByExpandingTildeInPath];
    NSString *agentPath = [agentDir stringByAppendingPathComponent:@"com.codetouchbar.studio.plist"];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:agentDir withIntermediateDirectories:YES attributes:nil error:nil];

    if (!enabled) {
        if ([fm fileExistsAtPath:agentPath]) {
            [fm removeItemAtPath:agentPath error:nil];
        }
        return;
    }

    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    NSDictionary *plist = @{
        @"Label": @"com.codetouchbar.studio",
        @"ProgramArguments": @[@"/usr/bin/open", @"-a", appPath],
        @"RunAtLoad": @YES,
        @"ProcessType": @"Interactive"
    };

    NSError *err = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:&err];
    if (data) {
        [data writeToFile:agentPath atomically:YES];
    }
}

- (BOOL)isLaunchAtLoginEnabled {
    NSString *agentPath = [@"~/Library/LaunchAgents/com.codetouchbar.studio.plist" stringByExpandingTildeInPath];
    return [[NSFileManager defaultManager] fileExistsAtPath:agentPath];
}

#pragma mark - Preferências e Armazenamento

- (NSMutableDictionary *)deepSeekKeychainQuery {
    return [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"com.codetouchbar.studio",
        (__bridge id)kSecAttrAccount: @"deepseek-api-key"
    } mutableCopy];
}

- (NSString *)deepSeekAPIKey {
    NSMutableDictionary *query = [self deepSeekKeychainQuery];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return nil;
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (BOOL)storeDeepSeekAPIKey:(NSString *)apiKey {
    NSData *data = [apiKey dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return NO;
    NSMutableDictionary *query = [self deepSeekKeychainQuery];
    NSDictionary *updates = @{(__bridge id)kSecValueData: data};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)updates);
    if (status == errSecItemNotFound) {
        [query addEntriesFromDictionary:updates];
        query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    return status == errSecSuccess;
}

- (BOOL)removeDeepSeekAPIKey {
    NSDictionary *query = [self deepSeekKeychainQuery];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    return status == errSecSuccess || status == errSecItemNotFound;
}

- (void)clearDeepSeekAPIKey {
    if (![self removeDeepSeekAPIKey]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Não foi possível remover a chave do Keychain.";
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.preferencesWindow completionHandler:nil];
        return;
    }
    self.deepseekAPIKeyField.stringValue = @"";
    self.deepseekAPIKeyField.placeholderString = @"Cole uma chave para habilitar saldo API";
    [self refreshStatuses];
}

- (NSURL *)settingsURL {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *supportURL = [fileManager URLForDirectory:NSApplicationSupportDirectory
                                            inDomain:NSUserDomainMask
                                   appropriateForURL:nil
                                              create:YES
                                               error:nil];
    NSURL *appURL = [supportURL URLByAppendingPathComponent:@"CodeTouchBar" isDirectory:YES];
    [fileManager createDirectoryAtURL:appURL withIntermediateDirectories:YES attributes:nil error:nil];
    return [appURL URLByAppendingPathComponent:@"settings.json"];
}

- (void)loadSettings {
    NSDictionary *defaults = @{
        @"refreshSeconds": @30,
        @"providers": @{
            @"codex": @YES,
            @"claude": @YES,
            @"antigravity": @YES,
            @"gemini": @YES,
            @"deepseek": @YES,
            @"ollama": @YES,
            @"perplexity": @YES
        },
        @"keepInMenuBar": @YES,
        @"launchAtLogin": @YES,
        @"limitWindow": @"auto",
        @"antigravityMode": @"auto",
        @"warningThreshold": @75,
        @"criticalThreshold": @90,
        @"showResetTime": @YES,
        @"notificationsEnabled": @YES
    };
    NSData *data = [NSData dataWithContentsOfURL:[self settingsURL]];
    NSDictionary *saved = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSMutableDictionary *merged = [defaults mutableCopy];
    if (saved) {
        if ([saved[@"providers"] isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *prov = [defaults[@"providers"] mutableCopy];
            NSDictionary *savedProv = saved[@"providers"];
            for (NSString *key in [self allProviders]) {
                if ([savedProv[key] isKindOfClass:NSNumber.class]) {
                    prov[key] = savedProv[key];
                }
            }
            merged[@"providers"] = prov;
        }
        for (NSString *key in @[@"refreshSeconds", @"keepInMenuBar", @"launchAtLogin", @"limitWindow", @"antigravityMode", @"warningThreshold", @"criticalThreshold", @"showResetTime", @"notificationsEnabled"]) {
            if (saved[key] != nil) {
                merged[key] = saved[key];
            }
        }
    }
    if ([merged[@"antigravityMode"] isEqualToString:@"steps"]) {
        merged[@"antigravityMode"] = @"auto";
    }
    self.settings = merged;
}

- (BOOL)providerEnabled:(NSString *)provider {
    return [self.settings[@"providers"][provider] boolValue];
}

- (void)configureRefreshTimer {
    [self.refreshTimer invalidate];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:[self.settings[@"refreshSeconds"] doubleValue]
                                                         target:self
                                                       selector:@selector(refreshStatuses)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (NSButton *)checkboxWithTitle:(NSString *)title provider:(NSString *)provider frame:(NSRect)frame {
    NSButton *checkbox = [NSButton checkboxWithTitle:title target:nil action:nil];
    checkbox.frame = frame;
    checkbox.state = [self providerEnabled:provider] ? NSControlStateValueOn : NSControlStateValueOff;
    return checkbox;
}

- (void)showPreferences {
    if (!self.preferencesWindow) {
        NSRect frame = NSMakeRect(0, 0, 500, 480);
        self.preferencesWindow = [[NSWindow alloc] initWithContentRect:frame
                                                             styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                               backing:NSBackingStoreBuffered
                                                                 defer:NO];
        self.preferencesWindow.title = @"Preferências do CodeTouchBar";
        self.preferencesWindow.delegate = self;
        [self.preferencesWindow setReleasedWhenClosed:NO];

        NSView *content = self.preferencesWindow.contentView;

        NSTabView *tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(16, 54, 468, 410)];

        // ==================== ABA 1: Geral ====================
        NSTabViewItem *tabGeneral = [[NSTabViewItem alloc] initWithIdentifier:@"general"];
        tabGeneral.label = @"Geral";
        NSView *viewGeneral = tabGeneral.view;

        NSTextField *providersLabel = [NSTextField labelWithString:@"Modelos de LLM Ativos na Touch Bar"];
        providersLabel.font = [NSFont boldSystemFontOfSize:13];
        providersLabel.frame = NSMakeRect(16, 340, 400, 20);
        [viewGeneral addSubview:providersLabel];

        // Coluna 1
        NSButton *codex = [self checkboxWithTitle:@"Codex" provider:@"codex" frame:NSMakeRect(16, 310, 130, 24)];
        NSButton *claude = [self checkboxWithTitle:@"Claude" provider:@"claude" frame:NSMakeRect(16, 280, 130, 24)];
        NSButton *antigravity = [self checkboxWithTitle:@"Antigravity" provider:@"antigravity" frame:NSMakeRect(16, 250, 130, 24)];
        NSButton *gemini = [self checkboxWithTitle:@"Gemini" provider:@"gemini" frame:NSMakeRect(16, 220, 130, 24)];

        // Coluna 2
        NSButton *deepseek = [self checkboxWithTitle:@"DeepSeek" provider:@"deepseek" frame:NSMakeRect(170, 310, 130, 24)];
        NSButton *ollama = [self checkboxWithTitle:@"Ollama (Local)" provider:@"ollama" frame:NSMakeRect(170, 280, 130, 24)];
        NSButton *perplexity = [self checkboxWithTitle:@"Perplexity" provider:@"perplexity" frame:NSMakeRect(170, 250, 130, 24)];

        self.providerCheckboxes = @{
            @"codex": codex,
            @"claude": claude,
            @"antigravity": antigravity,
            @"gemini": gemini,
            @"deepseek": deepseek,
            @"ollama": ollama,
            @"perplexity": perplexity
        };
        [viewGeneral addSubview:codex]; [viewGeneral addSubview:claude]; [viewGeneral addSubview:antigravity];
        [viewGeneral addSubview:gemini]; [viewGeneral addSubview:deepseek]; [viewGeneral addSubview:ollama]; [viewGeneral addSubview:perplexity];

        NSTextField *intervalLabel = [NSTextField labelWithString:@"Atualizar a cada:"];
        intervalLabel.frame = NSMakeRect(16, 175, 130, 22);
        [viewGeneral addSubview:intervalLabel];

        self.refreshIntervalPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(146, 172, 110, 26) pullsDown:NO];
        NSArray<NSNumber *> *intervals = @[@15, @30, @60, @120, @300];
        for (NSNumber *seconds in intervals) {
            NSString *title = (seconds.integerValue >= 60) ? [NSString stringWithFormat:@"%ld min", (long)(seconds.integerValue / 60)] : [NSString stringWithFormat:@"%ld s", (long)seconds.integerValue];
            [self.refreshIntervalPopup addItemWithTitle:title];
            self.refreshIntervalPopup.lastItem.representedObject = seconds;
        }
        for (NSMenuItem *item in self.refreshIntervalPopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"refreshSeconds"]]) {
                [self.refreshIntervalPopup selectItem:item];
                break;
            }
        }
        [viewGeneral addSubview:self.refreshIntervalPopup];

        NSTextField *behaviorLabel = [NSTextField labelWithString:@"Comportamento do Aplicativo"];
        behaviorLabel.font = [NSFont boldSystemFontOfSize:13];
        behaviorLabel.frame = NSMakeRect(16, 125, 400, 20);
        [viewGeneral addSubview:behaviorLabel];

        self.launchAtLoginCheckbox = [NSButton checkboxWithTitle:@"Abrir automaticamente ao iniciar sessão no macOS" target:nil action:nil];
        self.launchAtLoginCheckbox.frame = NSMakeRect(16, 95, 400, 24);
        self.launchAtLoginCheckbox.state = [self isLaunchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
        [viewGeneral addSubview:self.launchAtLoginCheckbox];

        self.keepInMenuBarCheckbox = [NSButton checkboxWithTitle:@"Manter ativo na Barra de Menus ao fechar a janela" target:nil action:nil];
        self.keepInMenuBarCheckbox.frame = NSMakeRect(16, 65, 400, 24);
        self.keepInMenuBarCheckbox.state = [self.settings[@"keepInMenuBar"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        [viewGeneral addSubview:self.keepInMenuBarCheckbox];

        NSTextField *deepseekKeyLabel = [NSTextField labelWithString:@"Chave da DeepSeek API (opcional; guardada no Keychain)"];
        deepseekKeyLabel.frame = NSMakeRect(16, 35, 430, 18);
        [viewGeneral addSubview:deepseekKeyLabel];
        self.deepseekAPIKeyField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(16, 6, 330, 24)];
        self.deepseekAPIKeyField.placeholderString = [self deepSeekAPIKey].length > 0
            ? @"Chave já configurada (digite para substituir)"
            : @"Cole uma chave para habilitar saldo API";
        [viewGeneral addSubview:self.deepseekAPIKeyField];
        NSButton *clearDeepseekKeyButton = [NSButton buttonWithTitle:@"Remover" target:self action:@selector(clearDeepSeekAPIKey)];
        clearDeepseekKeyButton.frame = NSMakeRect(354, 5, 92, 26);
        [viewGeneral addSubview:clearDeepseekKeyButton];

        [tabView addTabViewItem:tabGeneral];

        // ==================== ABA 2: Limites e Alertas ====================
        NSTabViewItem *tabLimits = [[NSTabViewItem alloc] initWithIdentifier:@"limits"];
        tabLimits.label = @"Controle de Limites";
        NSView *viewLimits = tabLimits.view;

        NSTextField *limitWindowLabel = [NSTextField labelWithString:@"Janela de Cota (Codex e Claude):"];
        limitWindowLabel.frame = NSMakeRect(16, 330, 210, 22);
        [viewLimits addSubview:limitWindowLabel];

        self.limitWindowPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(230, 327, 210, 26) pullsDown:NO];
        [self.limitWindowPopup addItemWithTitle:@"Automático (Maior uso)"];
        self.limitWindowPopup.lastItem.representedObject = @"auto";
        [self.limitWindowPopup addItemWithTitle:@"Sessão Atual (5 horas)"];
        self.limitWindowPopup.lastItem.representedObject = @"session";
        [self.limitWindowPopup addItemWithTitle:@"Cota Semanal (7 dias)"];
        self.limitWindowPopup.lastItem.representedObject = @"weekly";
        for (NSMenuItem *item in self.limitWindowPopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"limitWindow"]]) {
                [self.limitWindowPopup selectItem:item];
                break;
            }
        }
        [viewLimits addSubview:self.limitWindowPopup];

        NSTextField *agyModeLabel = [NSTextField labelWithString:@"Exibição do Antigravity:"];
        agyModeLabel.frame = NSMakeRect(16, 290, 210, 22);
        [viewLimits addSubview:agyModeLabel];

        self.antigravityModePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(230, 287, 210, 26) pullsDown:NO];
        [self.antigravityModePopup addItemWithTitle:@"Automático (5h ou semanal)"];
        self.antigravityModePopup.lastItem.representedObject = @"auto";
        [self.antigravityModePopup addItemWithTitle:@"Sempre Cota (%)"];
        self.antigravityModePopup.lastItem.representedObject = @"quota";
        for (NSMenuItem *item in self.antigravityModePopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"antigravityMode"]]) {
                [self.antigravityModePopup selectItem:item];
                break;
            }
        }
        [viewLimits addSubview:self.antigravityModePopup];

        NSTextField *warnLabel = [NSTextField labelWithString:@"Alerta de Aviso (%):"];
        warnLabel.frame = NSMakeRect(16, 245, 210, 22);
        [viewLimits addSubview:warnLabel];

        self.warningThresholdPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(230, 242, 110, 26) pullsDown:NO];
        for (NSNumber *val in @[@50, @60, @70, @75, @80]) {
            [self.warningThresholdPopup addItemWithTitle:[NSString stringWithFormat:@"%ld%%", (long)val.integerValue]];
            self.warningThresholdPopup.lastItem.representedObject = val;
        }
        for (NSMenuItem *item in self.warningThresholdPopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"warningThreshold"]]) {
                [self.warningThresholdPopup selectItem:item];
                break;
            }
        }
        [viewLimits addSubview:self.warningThresholdPopup];

        NSTextField *critLabel = [NSTextField labelWithString:@"Alerta Crítico (%):"];
        critLabel.frame = NSMakeRect(16, 205, 210, 22);
        [viewLimits addSubview:critLabel];

        self.criticalThresholdPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(230, 202, 110, 26) pullsDown:NO];
        for (NSNumber *val in @[@80, @85, @90, @95, @98]) {
            [self.criticalThresholdPopup addItemWithTitle:[NSString stringWithFormat:@"%ld%%", (long)val.integerValue]];
            self.criticalThresholdPopup.lastItem.representedObject = val;
        }
        for (NSMenuItem *item in self.criticalThresholdPopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"criticalThreshold"]]) {
                [self.criticalThresholdPopup selectItem:item];
                break;
            }
        }
        [viewLimits addSubview:self.criticalThresholdPopup];

        self.showResetTimeCheckbox = [NSButton checkboxWithTitle:@"Exibir contagem para reset na Touch Bar (ex: · 4h50m)" target:nil action:nil];
        self.showResetTimeCheckbox.frame = NSMakeRect(16, 155, 410, 24);
        self.showResetTimeCheckbox.state = [self.settings[@"showResetTime"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        [viewLimits addSubview:self.showResetTimeCheckbox];

        self.notificationsCheckbox = [NSButton checkboxWithTitle:@"Notificar no macOS ao atingir o limite crítico de cota" target:nil action:nil];
        self.notificationsCheckbox.frame = NSMakeRect(16, 120, 410, 24);
        self.notificationsCheckbox.state = [self.settings[@"notificationsEnabled"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        [viewLimits addSubview:self.notificationsCheckbox];

        [tabView addTabViewItem:tabLimits];

        [content addSubview:tabView];

        NSButton *cancel = [NSButton buttonWithTitle:@"Cancelar" target:self action:@selector(cancelPreferences)];
        cancel.frame = NSMakeRect(294, 14, 86, 32);
        [content addSubview:cancel];

        NSButton *save = [NSButton buttonWithTitle:@"Salvar" target:self action:@selector(savePreferences)];
        save.frame = NSMakeRect(386, 14, 96, 32);
        save.keyEquivalent = @"\r";
        [content addSubview:save];
    } else {
        for (NSString *provider in self.providerCheckboxes) {
            self.providerCheckboxes[provider].state = [self providerEnabled:provider] ? NSControlStateValueOn : NSControlStateValueOff;
        }
        for (NSMenuItem *item in self.refreshIntervalPopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"refreshSeconds"]]) [self.refreshIntervalPopup selectItem:item];
        }
        for (NSMenuItem *item in self.limitWindowPopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"limitWindow"]]) [self.limitWindowPopup selectItem:item];
        }
        for (NSMenuItem *item in self.antigravityModePopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"antigravityMode"]]) [self.antigravityModePopup selectItem:item];
        }
        for (NSMenuItem *item in self.warningThresholdPopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"warningThreshold"]]) [self.warningThresholdPopup selectItem:item];
        }
        for (NSMenuItem *item in self.criticalThresholdPopup.itemArray) {
            if ([item.representedObject isEqual:self.settings[@"criticalThreshold"]]) [self.criticalThresholdPopup selectItem:item];
        }
        self.showResetTimeCheckbox.state = [self.settings[@"showResetTime"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        self.notificationsCheckbox.state = [self.settings[@"notificationsEnabled"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        self.keepInMenuBarCheckbox.state = [self.settings[@"keepInMenuBar"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        self.launchAtLoginCheckbox.state = [self isLaunchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
        self.deepseekAPIKeyField.stringValue = @"";
        self.deepseekAPIKeyField.placeholderString = [self deepSeekAPIKey].length > 0
            ? @"Chave já configurada (digite para substituir)"
            : @"Cole uma chave para habilitar saldo API";
    }
    [NSApp activateIgnoringOtherApps:YES];
    [self.preferencesWindow center];
    [self.preferencesWindow makeKeyAndOrderFront:nil];
}

- (void)cancelPreferences {
    [self.preferencesWindow orderOut:nil];
}

- (void)savePreferences {
    NSMutableDictionary *providers = [NSMutableDictionary dictionary];
    for (NSString *provider in self.providerCheckboxes) {
        providers[provider] = @(self.providerCheckboxes[provider].state == NSControlStateValueOn);
    }
    if (![providers.allValues containsObject:@YES]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Selecione pelo menos um indicador.";
        alert.informativeText = @"O app precisa manter ao menos uma métrica na Touch Bar.";
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.preferencesWindow completionHandler:nil];
        return;
    }

    NSNumber *seconds = self.refreshIntervalPopup.selectedItem.representedObject ?: @30;
    NSString *limitWindow = self.limitWindowPopup.selectedItem.representedObject ?: @"auto";
    NSString *antigravityMode = self.antigravityModePopup.selectedItem.representedObject ?: @"auto";
    NSNumber *warnThresh = self.warningThresholdPopup.selectedItem.representedObject ?: @75;
    NSNumber *critThresh = self.criticalThresholdPopup.selectedItem.representedObject ?: @90;
    BOOL showResetTime = self.showResetTimeCheckbox.state == NSControlStateValueOn;
    BOOL notificationsEnabled = self.notificationsCheckbox.state == NSControlStateValueOn;
    BOOL keepInMenuBar = self.keepInMenuBarCheckbox.state == NSControlStateValueOn;
    BOOL shouldLaunchAtLogin = self.launchAtLoginCheckbox.state == NSControlStateValueOn;

    NSString *newDeepSeekKey = [self.deepseekAPIKeyField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (newDeepSeekKey.length > 0 && ![self storeDeepSeekAPIKey:newDeepSeekKey]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Não foi possível guardar a chave da DeepSeek no Keychain.";
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.preferencesWindow completionHandler:nil];
        return;
    }
    self.deepseekAPIKeyField.stringValue = @"";

    // Registra persistência no Início de Sessão via LaunchAgent
    [self setLaunchAtLoginEnabled:shouldLaunchAtLogin];

    self.settings = [@{
        @"refreshSeconds": seconds,
        @"providers": providers,
        @"keepInMenuBar": @(keepInMenuBar),
        @"launchAtLogin": @(shouldLaunchAtLogin),
        @"limitWindow": limitWindow,
        @"antigravityMode": antigravityMode,
        @"warningThreshold": warnThresh,
        @"criticalThreshold": critThresh,
        @"showResetTime": @(showResetTime),
        @"notificationsEnabled": @(notificationsEnabled)
    } mutableCopy];

    NSDictionary *json = self.settings;
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&error];
    if (!data || ![data writeToURL:[self settingsURL] options:NSDataWritingAtomic error:&error]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Não foi possível salvar as preferências.";
        alert.informativeText = error.localizedDescription ?: @"Erro ao gravar o arquivo de configuração.";
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.preferencesWindow completionHandler:nil];
        return;
    }

    [self configureRefreshTimer];
    [self.preferencesWindow orderOut:nil];
    [self updateControlWindow];
    [self updateMenuBarMenu];
    [self updateAppTouchBar];
    [self refreshStatuses];
}

#pragma mark - Execução de Scripts e Atualização de Status

- (NSDictionary *)runStatusScriptAtURL:(NSURL *)scriptURL provider:(NSString *)provider {
    NSArray<NSString *> *candidates = @[@"/opt/homebrew/bin/python3", @"/usr/local/bin/python3", @"/usr/bin/python3"];
    NSString *python = nil;
    for (NSString *candidate in candidates) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:candidate]) {
            python = candidate;
            break;
        }
    }
    if (!python) return @{@"provider": provider, @"kind": @"unavailable", @"state": @"unavailable", @"badge": @"Python ausente"};

    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [[NSPipe alloc] init];
    task.executableURL = [NSURL fileURLWithPath:python];
    task.arguments = @[scriptURL.path, @"--json"];
    task.standardOutput = pipe;
    task.standardError = [NSFileHandle fileHandleWithNullDevice];
    NSMutableDictionary<NSString *, NSString *> *environment = [NSProcessInfo.processInfo.environment mutableCopy];
    if ([provider isEqualToString:@"deepseek"]) {
        NSString *apiKey = [self deepSeekAPIKey];
        if (apiKey.length > 0) environment[@"DEEPSEEK_API_KEY"] = apiKey;
        else [environment removeObjectForKey:@"DEEPSEEK_API_KEY"];
    }
    task.environment = environment;
    dispatch_semaphore_t exited = dispatch_semaphore_create(0);
    task.terminationHandler = ^(NSTask *finishedTask) {
        (void)finishedTask;
        dispatch_semaphore_signal(exited);
    };
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) return @{@"provider": provider, @"kind": @"unavailable", @"state": @"unavailable", @"badge": @"Indisponível"};
    if (dispatch_semaphore_wait(exited, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) != 0) {
        if (task.isRunning) [task terminate];
        [task waitUntilExit];
        return @{@"provider": provider, @"kind": @"unavailable", @"state": @"unavailable", @"badge": @"Tempo esgotado"};
    }

    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSDictionary *metric = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (task.terminationStatus == 0 && [metric isKindOfClass:NSDictionary.class] && [metric[@"badge"] isKindOfClass:NSString.class]) {
        return metric;
    }
    return @{@"provider": provider, @"kind": @"unavailable", @"state": @"unavailable", @"badge": @"Indisponível"};
}

- (void)refreshStatuses {
    // Timer ticks and manual refreshes can arrive while provider scripts are
    // still running. Keep one refresh batch active to prevent stale results
    // from racing newer results and spawning unbounded processes.
    if (self.refreshInProgress) return;
    self.refreshInProgress = YES;

    NSURL *scriptsURL = [[NSBundle mainBundle].resourceURL URLByAppendingPathComponent:@"scripts"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:scriptsURL.path]) {
        scriptsURL = [NSURL fileURLWithPath:@"scripts"];
    }

    NSDictionary<NSString *, NSString *> *scripts = @{
        @"codex": @"codex_status.py",
        @"claude": @"claude_status.py",
        @"antigravity": @"antigravity_status.py",
        @"gemini": @"gemini_status.py",
        @"deepseek": @"deepseek_status.py",
        @"ollama": @"ollama_status.py",
        @"perplexity": @"perplexity_status.py"
    };

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    [scripts enumerateKeysAndObjectsUsingBlock:^(NSString *provider, NSString *filename, BOOL *stop) {
        (void)stop;
        if (![self providerEnabled:provider]) {
            self.statuses[provider] = @"Desativado";
            self.providerMetrics[provider] = @{@"provider": provider, @"kind": @"unavailable", @"state": @"disabled", @"badge": @"Desativado"};
            return;
        }
        dispatch_group_async(group, queue, ^{
            NSDictionary *metric = [self runStatusScriptAtURL:[scriptsURL URLByAppendingPathComponent:filename] provider:provider];
            NSString *value = [metric[@"badge"] isKindOfClass:NSString.class] ? metric[@"badge"] : @"Indisponível";
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.providerMetrics[provider] = metric;
                self.statuses[provider] = value;
            });
        });
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        self.refreshInProgress = NO;
        self.lastRefreshDate = [NSDate date];
        [self updateTouchBarProviderButtons];
        [self updateAppTouchBar];
        if (self.isModalTouchBarPresented && self.modalTouchBar) {
            self.modalTouchBar.defaultItemIdentifiers = [self identifiersForCurrentStateWithClose:YES];
        }
        [self updateMenuBarMenu];
        [self updateControlWindow];
        [self checkLimitsAndNotify];
    });
}

- (void)quit {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
