//
//  SDKeyNavigableTableView.h
//  Songs
//
//  Created by Steven on 8/22/13.
//  Copyright (c) 2013 Steven Degutis. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SDKeyNavigableTableView : NSTableView

- (void) moveUpAndExtend:(BOOL)extend;
- (void) moveDownAndExtend:(BOOL)extend;

@end
