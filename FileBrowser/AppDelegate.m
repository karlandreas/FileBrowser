//
//  AppDelegate.m
//  FileBrowser
//
//  Created by Super User on 20.08.13.
//  Copyright (c) 2013 KAjohansen. All rights reserved.
//

#import "AppDelegate.h"
#import "sshConnect.h"
#import "FileSystemNode.h"

@implementation AppDelegate

const char *username="superuser";
const char *server_ip = "10.0.0.10";

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    initSSHconnection(username, server_ip);
}

- (IBAction)closeConnection:(id)sender {
    go_shutdown();
}

- (IBAction)callListFolder:(id)sender {
    const char *command = "ls";
    const char *folderList = callSSHcommand(command);
    NSString *folders = [[NSString alloc] initWithCString:folderList encoding:NSUTF8StringEncoding];
    NSArray *folderArray = [folders componentsSeparatedByString:@"\n"];
    NSLog(@"%@", folderArray);
}

#pragma mark - NSBrowser
- (void)browser:(NSBrowser *)sender createRowsForColumn:(NSInteger)column inMatrix:(NSMatrix *)matrix {
    NSLog(@"browser delegate called");
}

// This method is optional, but makes the code much easier to understand
- (id)rootItemForBrowser:(NSBrowser *)browser {
    if (_rootNode == nil) {
        _rootNode = [[FileSystemNode alloc] initWithURL:[NSURL fileURLWithPath:@"/"]];
    }
    return _rootNode;
}

- (NSInteger)browser:(NSBrowser *)browser numberOfChildrenOfItem:(id)item {
    FileSystemNode *node = (FileSystemNode *)item;
    return node.children.count;
}

- (id)browser:(NSBrowser *)browser child:(NSInteger)index ofItem:(id)item {
    FileSystemNode *node = (FileSystemNode *)item;
    return [node.children objectAtIndex:index];
}

- (BOOL)browser:(NSBrowser *)browser isLeafItem:(id)item {
    FileSystemNode *node = (FileSystemNode *)item;
    return !node.isDirectory;
}

- (id)browser:(NSBrowser *)browser objectValueForItem:(id)item {
    FileSystemNode *node = (FileSystemNode *)item;
    return node.displayName;
}

@end
