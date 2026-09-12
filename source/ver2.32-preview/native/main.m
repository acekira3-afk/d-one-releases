#import <Cocoa/Cocoa.h>
#import <Security/Security.h>
#import <WebKit/WebKit.h>

static NSString *const DOneKeyService = @"local.codex.prioritydesk.mascotdev.model-keys";

static NSString *DOneReadKey(NSString *provider) {
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService:DOneKeyService,
                            (__bridge id)kSecAttrAccount:provider,
                            (__bridge id)kSecReturnData:@YES,
                            (__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitOne};
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess) return nil;
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static BOOL DOneSaveKey(NSString *provider, NSString *key) {
    NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *base = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                           (__bridge id)kSecAttrService:DOneKeyService,
                           (__bridge id)kSecAttrAccount:provider};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)base, (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData:data});
    if (status == errSecItemNotFound) {
        NSMutableDictionary *item = [base mutableCopy];
        item[(__bridge id)kSecValueData] = data;
        status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
    }
    return status == errSecSuccess;
}

static void DOneClearWebBackground(NSView *view) {
    view.wantsLayer = YES;
    view.layer.backgroundColor = NSColor.clearColor.CGColor;
    view.layer.opaque = NO;
    if ([view isKindOfClass:NSScrollView.class]) {
        NSScrollView *scroll = (NSScrollView *)view;
        scroll.drawsBackground = NO;
        scroll.backgroundColor = NSColor.clearColor;
    }
    for (NSView *child in view.subviews) DOneClearWebBackground(child);
}

@interface DOneWebView : WKWebView
@end

@implementation DOneWebView
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSString *script = @"if(document.documentElement.classList.contains('mascot-mode'))document.getElementById('mascotMenu').classList.add('open')";
    [self evaluateJavaScript:script completionHandler:nil];
    return nil;
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler, WKNavigationDelegate>
@property NSWindow *window;
@property WKWebView *webView;
@property NSMutableDictionary<NSString *, NSWindow *> *detailWindows;
@property NSMutableDictionary<NSString *, WKWebView *> *detailWebViews;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.detailWindows = [NSMutableDictionary dictionary];
    self.detailWebViews = [NSMutableDictionary dictionary];
    NSRect frame = NSMakeRect(0, 0, 280, 76);
    self.window = [[NSWindow alloc] initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"D-one";
    self.window.delegate = self;
    self.window.minSize = NSMakeSize(220, 44);
    self.window.maxSize = NSMakeSize(380, 620);
    self.window.level = NSFloatingWindowLevel;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.titlebarAppearsTransparent = YES;
    self.window.opaque = NO;
    self.window.backgroundColor = NSColor.clearColor;
    self.window.movableByWindowBackground = YES;
    NSRect screen = NSScreen.mainScreen.visibleFrame;
    [self.window setFrameOrigin:NSMakePoint(NSMaxX(screen) - frame.size.width - 24, NSMaxY(screen) - frame.size.height - 24)];

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    [config.userContentController addScriptMessageHandler:self name:@"windowMode"];
    [config.userContentController addScriptMessageHandler:self name:@"secret"];
    [config.userContentController addScriptMessageHandler:self name:@"model"];
    [config.userContentController addScriptMessageHandler:self name:@"detailWindow"];
    self.webView = [[DOneWebView alloc] initWithFrame:frame configuration:config];
    self.webView.underPageBackgroundColor = NSColor.clearColor;
    self.webView.wantsLayer = YES;
    self.webView.layer.backgroundColor = NSColor.clearColor.CGColor;
    self.webView.layer.opaque = NO;
    @try { [self.webView setValue:@NO forKey:@"drawsBackground"]; } @catch (__unused NSException *exception) {}
    DOneClearWebBackground(self.webView);
    self.webView.navigationDelegate = self;
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.window.contentView = self.webView;
    NSURL *url = [NSBundle.mainBundle URLForResource:@"index" withExtension:@"html"];
    [self.webView loadFileURL:url allowingReadAccessToURL:url.URLByDeletingLastPathComponent];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    DOneClearWebBackground(webView);
}
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"detailWindow"] && [message.body isKindOfClass:NSDictionary.class]) {
        [self handleDetailWindow:message.body];
        return;
    }
    if ([message.name isEqualToString:@"secret"] && [message.body isKindOfClass:NSDictionary.class]) {
        NSString *provider = message.body[@"provider"];
        NSString *key = message.body[@"key"];
        if (provider.length && key.length) DOneSaveKey(provider, key);
        return;
    }
    if ([message.name isEqualToString:@"model"] && [message.body isKindOfClass:NSDictionary.class]) {
        [self requestModel:message.body];
        return;
    }
    if (![message.name isEqualToString:@"windowMode"]) return;
    BOOL compact = NO;
    BOOL mascot = NO;
    NSInteger rows = 0;
    if ([message.body isKindOfClass:NSDictionary.class]) {
        compact = [message.body[@"compact"] boolValue];
        mascot = [message.body[@"mascot"] boolValue];
        rows = [message.body[@"rows"] integerValue];
    } else {
        compact = [message.body boolValue];
    }
    NSRect old = self.window.frame;
    CGFloat width = mascot ? 250 : 280;
    CGFloat height = mascot ? 370 : (compact ? 72 : MIN(700, MAX(76, 82 + rows * 38)));
    if (mascot) width = 300;
    NSWindowStyleMask normalMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable;
    self.window.styleMask = mascot ? NSWindowStyleMaskBorderless : normalMask;
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.titlebarAppearsTransparent = YES;
    NSRect next = NSMakeRect(NSMaxX(old) - width, NSMaxY(old) - height, width, height);
    [[self.window standardWindowButton:NSWindowCloseButton] setHidden:mascot];
    [[self.window standardWindowButton:NSWindowMiniaturizeButton] setHidden:mascot];
    [[self.window standardWindowButton:NSWindowZoomButton] setHidden:mascot];
    self.window.hasShadow = !mascot;
    [self.window setFrame:next display:YES animate:YES];
}

- (NSString *)javaScriptLiteral:(NSString *)value {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value ?: @""] options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (json.length < 2) return @"\"\"";
    return [json substringWithRange:NSMakeRange(1, json.length - 2)];
}

- (void)openDetailWindowForTask:(NSString *)taskID title:(NSString *)title {
    if (!taskID.length) return;
    NSWindow *existing = self.detailWindows[taskID];
    if (existing) {
        existing.title = title.length ? title : @"子便签";
        [existing makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        return;
    }
    NSRect mainFrame = self.window.frame;
    NSUInteger offset = self.detailWindows.count % 5;
    NSRect frame = NSMakeRect(NSMinX(mainFrame) - 286 - offset * 18,
                              NSMaxY(mainFrame) - 250 - offset * 20,
                              270, 250);
    NSWindow *detail = [[NSWindow alloc] initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    detail.delegate = self;
    detail.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    detail.minSize = NSMakeSize(230, 185);
    detail.maxSize = NSMakeSize(420, 620);
    detail.level = NSFloatingWindowLevel;
    detail.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    detail.titleVisibility = NSWindowTitleVisible;
    detail.titlebarAppearsTransparent = NO;
    detail.titlebarSeparatorStyle = NSTitlebarSeparatorStyleLine;
    detail.opaque = YES;
    detail.backgroundColor = NSColor.windowBackgroundColor;
    detail.title = title.length ? title : @"子便签";
    detail.movableByWindowBackground = NO;

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    [config.userContentController addScriptMessageHandler:self name:@"detailWindow"];
    WKWebView *view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height) configuration:config];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    detail.contentView = view;
    NSURL *baseURL = [NSBundle.mainBundle URLForResource:@"subnote" withExtension:@"html"];
    NSURLComponents *parts = [NSURLComponents componentsWithURL:baseURL resolvingAgainstBaseURL:NO];
    parts.queryItems = @[[NSURLQueryItem queryItemWithName:@"task" value:taskID]];
    [view loadFileURL:parts.URL allowingReadAccessToURL:baseURL.URLByDeletingLastPathComponent];
    self.detailWindows[taskID] = detail;
    self.detailWebViews[taskID] = view;
    [detail makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)handleDetailWindow:(NSDictionary *)body {
    NSString *action = [body[@"action"] isKindOfClass:NSString.class] ? body[@"action"] : @"";
    NSString *taskID = [body[@"taskId"] isKindOfClass:NSString.class] ? body[@"taskId"] : @"";
    NSString *title = [body[@"title"] isKindOfClass:NSString.class] ? body[@"title"] : @"";
    if ([action isEqualToString:@"open"]) {
        [self openDetailWindowForTask:taskID title:title];
        return;
    }
    NSWindow *detail = self.detailWindows[taskID];
    WKWebView *view = self.detailWebViews[taskID];
    if ([action isEqualToString:@"close"]) {
        [detail orderOut:nil];
        [self.detailWindows removeObjectForKey:taskID];
        [self.detailWebViews removeObjectForKey:taskID];
        return;
    }
    if ([action isEqualToString:@"rename"]) {
        detail.title = title.length ? title : @"子便签";
        NSString *script = [NSString stringWithFormat:@"window.updateParentTitle(%@)", [self javaScriptLiteral:title]];
        [view evaluateJavaScript:script completionHandler:nil];
        return;
    }
    if ([action isEqualToString:@"theme"] && view) {
        NSInteger priority = [body[@"priority"] integerValue];
        NSString *script = [NSString stringWithFormat:@"window.updateParentTheme(%ld)", (long)priority];
        [view evaluateJavaScript:script completionHandler:nil];
        return;
    }
    if ([action isEqualToString:@"resize"] && detail) {
        NSInteger rows = [body[@"rows"] integerValue];
        CGFloat height = MIN(560, MAX(185, 137 + rows * 48));
        NSRect old = detail.frame;
        NSRect next = NSMakeRect(old.origin.x, NSMaxY(old) - height, old.size.width, height);
        [detail setFrame:next display:YES animate:YES];
        return;
    }
    if ([action isEqualToString:@"changed"]) {
        [self.webView evaluateJavaScript:@"window.refreshTasksFromStorage()" completionHandler:nil];
    }
}

- (void)sendModelResult:(NSDictionary *)result {
    NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *script = [NSString stringWithFormat:@"window.onModelResult(%@)", json ?: @"{}"];
    dispatch_async(dispatch_get_main_queue(), ^{ [self.webView evaluateJavaScript:script completionHandler:nil]; });
}

- (NSURL *)historyURL {
    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *folder = [support URLByAppendingPathComponent:@"D-one" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    return [folder URLByAppendingPathComponent:@"chat-history.json"];
}

- (void)appendHistory:(NSDictionary *)entry {
    NSURL *url = [self historyURL];
    NSData *oldData = [NSData dataWithContentsOfURL:url];
    NSArray *old = oldData ? [NSJSONSerialization JSONObjectWithData:oldData options:0 error:nil] : nil;
    NSMutableArray *items = [old isKindOfClass:NSArray.class] ? [old mutableCopy] : [NSMutableArray array];
    [items addObject:entry];
    if (items.count > 1000) [items removeObjectsInRange:NSMakeRange(0, items.count - 1000)];
    NSData *data = [NSJSONSerialization dataWithJSONObject:items options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToURL:url options:NSDataWritingAtomic error:nil];
}

- (void)requestModel:(NSDictionary *)body {
    NSString *requestID = body[@"id"] ?: @"";
    NSString *provider = body[@"provider"] ?: @"openai";
    NSString *model = body[@"model"] ?: @"";
    NSString *prompt = body[@"prompt"] ?: @"";
    NSString *task = body[@"task"] ?: @"";
    NSString *key = DOneReadKey(provider);
    if (!key.length) {
        [self sendModelResult:@{@"id":requestID,@"ok":@NO,@"code":@"MISSING_KEY"}];
        return;
    }
    NSString *urlString = @"https://api.openai.com/v1/chat/completions";
    if ([provider isEqualToString:@"deepseek"]) urlString = @"https://api.deepseek.com/chat/completions";
    if ([provider isEqualToString:@"kimi"]) urlString = @"https://api.moonshot.ai/v1/chat/completions";
    NSString *system = @"你是 D-one 桌面任务助手。结合当前任务回答。只输出一到两行简短中文，不超过六十个汉字；给出能立刻执行的建议，不要寒暄。";
    NSString *user = [NSString stringWithFormat:@"当前任务：%@\n问题：%@", task, prompt];
    NSDictionary *payload = @{@"model":model,
                              @"messages":@[@{@"role":@"system",@"content":system},@{@"role":@"user",@"content":user}],
                              @"stream":@NO};
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = payloadData;
    request.timeoutInterval = 45;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self sendModelResult:@{@"id":requestID,@"ok":@NO,@"error":error.localizedDescription ?: @"网络错误"}];
            return;
        }
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *text = nil;
        NSArray *choices = [json[@"choices"] isKindOfClass:NSArray.class] ? json[@"choices"] : nil;
        if (choices.count) text = choices[0][@"message"][@"content"];
        if (!text.length) {
            NSString *message = [json[@"error"][@"message"] isKindOfClass:NSString.class] ? json[@"error"][@"message"] : @"模型没有返回文字";
            [self sendModelResult:@{@"id":requestID,@"ok":@NO,@"error":message}];
            return;
        }
        NSDictionary *entry = @{@"time":@([[NSDate date] timeIntervalSince1970]),@"provider":provider,@"model":model,@"task":task,@"prompt":prompt,@"answer":text};
        [self appendHistory:entry];
        [self sendModelResult:@{@"id":requestID,@"ok":@YES,@"text":text}];
    }] resume];
}
- (BOOL)windowShouldClose:(NSWindow *)sender {
    if (sender != self.window) {
        NSString *matched = nil;
        for (NSString *taskID in self.detailWindows) {
            if (self.detailWindows[taskID] == sender) { matched = taskID; break; }
        }
        [sender orderOut:nil];
        if (matched) {
            [self.detailWindows removeObjectForKey:matched];
            [self.detailWebViews removeObjectForKey:matched];
        }
        return NO;
    }
    [sender orderOut:nil];
    return NO;
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (!self.window.isVisible) {
        [self.window makeKeyAndOrderFront:nil];
    }
    [NSApp activateIgnoringOtherApps:YES];
    return YES;
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [AppDelegate new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
