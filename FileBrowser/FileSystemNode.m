//
//  FileSystemNode.m
//  FileBrowser
//
//  Created by Super User on 20.08.13.
//  Copyright (c) 2013 KAjohansen. All rights reserved.
//



#import "FileSystemNode.h"

@implementation FileSystemNode

- (id)initWithURL:(NSURL *)url {
    if (self = [super init]) {
        _url = url;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ - %@", super.description, _url];
}

@dynamic displayName, children, isDirectory, icon, labelColor;

- (NSString *)displayName {
    id value = nil;
    NSError *error = nil;
    BOOL success = NO;
    
    success = [_url getResourceValue:&value forKey:NSURLLocalizedNameKey error:&error];
    if (success && !value) { //If we got a nil value for the localized name, we will try the non-localized name
	success = [_url getResourceValue:&value forKey:NSURLNameKey error:&error];
    }
    
    if (success) {
	if (value) {
	    return value;
	} else {
	    return @""; //An empty string is more appropriate than nil
	}
	
    } else {
	return [error localizedDescription];
    }
}

- (NSImage *)icon {
    return [[NSWorkspace sharedWorkspace] iconForFile:[_url path]];
}

- (BOOL)isDirectory {
    id value = nil;
    [_url getResourceValue:&value forKey:NSURLIsDirectoryKey error:NULL];
    return [value boolValue];
}

- (NSColor *)labelColor {
    id value = nil;
    [_url getResourceValue:&value forKey:NSURLLabelColorKey error:NULL];
    return value;
}

- (NSArray *)children {
    if (_children == nil || _childrenDirty) {
        // This logic keeps the same pointers around, if possible.
        NSMutableDictionary *newChildren = [NSMutableDictionary new];
        
        NSString *parentPath = [_url path];
        NSArray *contentsAtPath = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:parentPath error:NULL];
	
	if (contentsAtPath) {	// We don't deal with the error
	    for (NSString *filename in contentsAtPath) {
		// Use the filename as a key and see if it was around and reuse it, if possible
		if (_children != nil) {
		    FileSystemNode *oldChild = [_children objectForKey:filename];
		    if (oldChild != nil) {
			[newChildren setObject:oldChild forKey:filename];
			continue;
		    }
		}
		// We didn't find it, add a new one
		NSString *fullPath = [parentPath stringByAppendingFormat:@"/%@", filename];
		NSURL *childURL = [NSURL fileURLWithPath:fullPath];
		if (childURL != nil) {
		    // Wrap the child url with our node
		    FileSystemNode *node = [[FileSystemNode alloc] initWithURL:childURL];
		    [newChildren setObject:node forKey:filename];
		}
	    }
	}
        
        _children = newChildren;
        _childrenDirty = NO;
    }
    
    NSArray *result = [_children allValues];
    // Sort the children by the display name and return it
    result = [result sortedArrayUsingComparator:^(id obj1, id obj2) {
        NSString *objName = [obj1 displayName];
        NSString *obj2Name = [obj2 displayName];
        NSComparisonResult result = [objName compare:obj2Name options:NSNumericSearch | NSCaseInsensitiveSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch range:NSMakeRange(0, [objName length]) locale:[NSLocale currentLocale]];
        return result;
    }];
    return result;
}

- (void)invalidateChildren {
    _childrenDirty = YES;
    for (FileSystemNode *child in [_children allValues]) {
        [child invalidateChildren];
    }
}

@end
