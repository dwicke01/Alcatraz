// Alcatraz.m
//
// Copyright (c) 2013 Marin Usalj | supermar.in
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


#import "Alcatraz.h"
#import "ATZPluginWindowController.h"
#import "ATZAlcatrazPackage.h"
#import "ATZGit.h"

#import "Aspects.h"

static Alcatraz *sharedPlugin;

@implementation Alcatraz

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];

    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

+ (Alcatraz *)sharedPlugin {
    return sharedPlugin;
}

+ (NSString *)localizedStringForKey:(NSString *)key {
    return [[self sharedPlugin].bundle localizedStringForKey:key value:nil table:nil];
}

- (id)initWithBundle:(NSBundle *)plugin {
    if (self = [super init]) {
        self.bundle = plugin;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self createMenuItem];
            self.alcatrazDockMenuItem = [[NSMenuItem alloc] initWithTitle:@"Package Manager" action:@selector(bringPackageManagerToFront) keyEquivalent:@""];
            self.alcatrazDockMenuItem.target = self;
            [self swizzleApplicationDockMenu];
        }];
        [self updateAlcatraz];
    }
    return self;
}

#pragma mark - Private

- (void)createMenuItem {
    NSMenuItem *windowMenuItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
    NSMenuItem *pluginManagerItem = [[NSMenuItem alloc] initWithTitle:@"Package Manager"
                                                               action:@selector(checkForCMDLineToolsAndOpenWindow)
                                                        keyEquivalent:@"9"];
    pluginManagerItem.keyEquivalentModifierMask = NSCommandKeyMask | NSShiftKeyMask;
    pluginManagerItem.target = self;

    [windowMenuItem.submenu insertItem:pluginManagerItem
                               atIndex:[windowMenuItem.submenu indexOfItemWithTitle:@"Bring All to Front"] - 1];
}

- (void)checkForCMDLineToolsAndOpenWindow {
    if ([self hasNSURLSessionAvailable]) {
        if ([ATZGit areCommandLineToolsAvailable])
            [self loadWindowAndPutInFront];
        else
            [self presentAlertWithMessageKey:@"CMDLineToolsWarning"];
    } else {
        [self presentAlertWithMessageKey:@"MavericksOnlyWarning"];
    }
}

- (void)loadWindowAndPutInFront {
    if (!self.windowController.window)
        self.windowController = [[ATZPluginWindowController alloc] initWithBundle:self.bundle];

    [[self.windowController window] makeKeyAndOrderFront:self];
    [self.windowController reloadPackages:nil];
}

- (BOOL)hasNSURLSessionAvailable {
    return NSClassFromString(@"NSURLSession") != nil;
}

- (void)presentAlertWithMessageKey:(NSString *)messageKey {
    NSAlert *alert = [NSAlert new];
    alert.messageText = [[self class] localizedStringForKey:messageKey];
    [alert runModal];
}

- (void)updateAlcatraz {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^{
        [ATZAlcatrazPackage update];
    }];
}


#pragma Dock Menu Item Methods

-(void)swizzleApplicationDockMenu {
    Class xcodeAppDelegateClass = NSClassFromString(@"IDEApplicationController");
    
    [xcodeAppDelegateClass aspect_hookSelector:@selector(applicationDockMenu:) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info, NSEvent *event) {
        NSMenu *dockMenu;
        NSInvocation *invocation = info.originalInvocation;
        [invocation invoke];
        [invocation getReturnValue:&dockMenu];
        CFRetain((__bridge CFTypeRef)(dockMenu));
        if (self.windowController.window != nil && [self.windowController.window isVisible]) {
            if ([self.alcatrazDockMenuItem menu]) {
                [[self.alcatrazDockMenuItem menu] removeItem:self.alcatrazDockMenuItem];
            }
            NSUInteger indexOfOpenDeveloperTools = [dockMenu indexOfItemWithTitle:@"Open Developer Tool"];
            [dockMenu insertItem:[NSMenuItem separatorItem] atIndex:indexOfOpenDeveloperTools];
            [dockMenu insertItem:self.alcatrazDockMenuItem atIndex:indexOfOpenDeveloperTools];
        }
        [invocation setReturnValue:&dockMenu];
    }error:NULL];
}

-(void)bringPackageManagerToFront {
    [[self.windowController window] makeKeyAndOrderFront:self];
}


@end