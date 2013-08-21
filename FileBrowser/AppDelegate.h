//
//  AppDelegate.h
//  FileBrowser
//
//  Created by Super User on 20.08.13.
//  Copyright (c) 2013 KAjohansen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FileSystemNode;
@interface AppDelegate : NSObject <NSApplicationDelegate, NSBrowserDelegate> {
    @private
    FileSystemNode *_rootNode;
}

@property (assign) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSBrowser *browser;


@end
