//
//  SDPlaylistsViewController.m
//  Songs
//
//  Created by Steven on 8/19/13.
//  Copyright (c) 2013 Steven Degutis. All rights reserved.
//

#import "SDSourceListViewController.h"

#import "SDUserDataManager.h"
#import "SDMusicPlayer.h"



static NSString* SDSongDragType = @"SDSongDragType";
static NSString* SDPlaylistDragType = @"SDPlaylistDragType";



@interface SDTableRowView : NSTableRowView
@end

@implementation SDTableRowView

- (void)drawSelectionInRect:(NSRect)dirtyRect {
    if ([[self window] firstResponder] == [self superview] && [[self window] isKeyWindow]) {
        [[NSColor colorWithDeviceHue:206.0/360.0 saturation:0.67 brightness:0.92 alpha:1.0] setFill];
        [[NSBezierPath bezierPathWithRect:self.bounds] fill];
    }
    else {
        [[NSColor colorWithDeviceHue:206.0/360.0 saturation:0.67 brightness:0.92 alpha:0.5] setFill];
        [[NSBezierPath bezierPathWithRect:self.bounds] fill];
    }
}

@end





@interface SDSourceListViewController ()

@property (weak) IBOutlet NSTableView* playlistsTableView;

@end

@implementation SDSourceListViewController

- (NSString*) nibName {
    return @"SourceListView";
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) loadView {
    [super loadView];
    
    [self.playlistsTableView setTarget:self];
    [self.playlistsTableView setDoubleAction:@selector(doubleClickedThing:)];
    
    [self.playlistsTableView registerForDraggedTypes:@[SDPlaylistDragType]];
    [self.playlistsTableView registerForDraggedTypes:@[SDSongDragType]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playlistAddedNotification:) name:SDPlaylistAddedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playlistRenamedNotification:) name:SDPlaylistRenamedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playlistRemovedNotification:) name:SDPlaylistRemovedNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentSongDidChange:) name:SDCurrentSongDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerStatusDidChange:) name:SDPlayerStatusDidChangeNotification object:nil];
}




- (void) refreshKeepingCurrentSelection {
    NSInteger row = [self.playlistsTableView selectedRow];
    [self.playlistsTableView reloadData];
    [self.playlistsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}



- (void) playlistAddedNotification:(NSNotification*)note {
    [self refreshKeepingCurrentSelection];
}

- (void) playlistRenamedNotification:(NSNotification*)note {
    [self refreshKeepingCurrentSelection];
}

- (void) playlistRemovedNotification:(NSNotification*)note {
    [self.playlistsTableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [[SDSharedData() playlists] count];
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    SDPlaylist* playlist = [[SDSharedData() playlists] objectAtIndex:row];
    BOOL isPlaying = ([[SDMusicPlayer sharedPlayer] isPlaying] && playlist == [[SDMusicPlayer sharedPlayer] currentPlaylist]);
    
    NSTableCellView *result = [tableView makeViewWithIdentifier:@"ExistingPlaylist" owner:self];
    [result textField].stringValue = [playlist title];
    [[result imageView] setHidden: !isPlaying];
    return result;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    return [[SDTableRowView alloc] init];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    [self.playlistsViewDelegate selectPlaylist: [self selectedPlaylist]];
}



- (SDPlaylist*) selectedPlaylist {
    NSInteger row = [self.playlistsTableView selectedRow];
    
    if (row == -1)
        return nil;
    else
        return [[SDSharedData() playlists] objectAtIndex:row];
}


- (BOOL) respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(startRenamingPlaylist:)) {
        if ([NSApp currentEvent] == nil)
            return YES;
        
        NSInteger row = [self.playlistsTableView clickedRow];
        
        if (row == -1)
            return NO;
        
        SDPlaylist* playlist = [[SDSharedData() playlists] objectAtIndex:row];
        if ([playlist isMasterPlaylist])
            return NO;
        
        return YES;
    }
    else if (aSelector == @selector(severelyDeleteSomething:)) {
        if ([[self.playlistsTableView window] firstResponder] != self.playlistsTableView)
            return NO;
        
        if ([self selectedPlaylist] == nil)
            return NO;
        
        if ([[self selectedPlaylist] isMasterPlaylist])
            return NO;
        
        return YES;
    }
    else {
        return [super respondsToSelector:aSelector];
    }
}

- (IBAction) severelyDeleteSomething:(id)sender {
    [SDSharedData() deletePlaylist: [self selectedPlaylist]];
    [self.playlistsTableView reloadData];
}

- (void) selectPlaylist:(SDPlaylist*)playlist {
    NSUInteger idx = [[SDSharedData() playlists] indexOfObject:playlist];
    [self.playlistsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx]
                         byExtendingSelection:NO];
    
    [self.playlistsViewDelegate selectPlaylist:playlist];
}

- (void) doubleClickedThing:(id)sender {
    NSInteger row = [self.playlistsTableView clickedRow];
    
    if (row < 0)
        return;
    
    SDPlaylist* playlist = [[SDSharedData() playlists] objectAtIndex:row];
    [self.playlistsViewDelegate playPlaylist:playlist];
}













#pragma mark - Playlists, Drag / Drop

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    SDPlaylist* playlist = [[SDSharedData() playlists] objectAtIndex: [rowIndexes firstIndex]];
    NSUInteger playlistIndex = [[SDSharedData() playlists] indexOfObject:playlist];
    
    [pboard setPropertyList:@(playlistIndex)
                    forType:SDPlaylistDragType];
    
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
    if ([[[info draggingPasteboard] types] containsObject: SDPlaylistDragType]) {
        if (operation == NSTableViewDropAbove)
            return NSDragOperationMove;
        else
            return NSDragOperationNone;
    }
    else {
        if (operation == NSTableViewDropOn && ![[[SDSharedData() playlists] objectAtIndex: row] isMasterPlaylist]) {
            return NSDragOperationCopy;
        }
        else
            return NSDragOperationNone;
    }
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id < NSDraggingInfo >)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
    if ([[[info draggingPasteboard] types] containsObject: SDPlaylistDragType]) {
        NSNumber* playlistIndex = [[info draggingPasteboard] propertyListForType:SDPlaylistDragType];
        SDPlaylist* movingPlaylist = [[SDSharedData() playlists] objectAtIndex:[playlistIndex integerValue]];

        [SDSharedData() movePlaylist:movingPlaylist
                             toIndex:row];
        
        return YES;
    }
    else {
        NSDictionary* data = [[info draggingPasteboard] propertyListForType:SDSongDragType];
        NSArray* uuids = [data objectForKey:@"uuids"];
        NSArray* songs = [SDUserDataManager songsForUUIDs:uuids];
        
        SDPlaylist* toPlaylist = [[SDSharedData() playlists] objectAtIndex: row];
        [toPlaylist addSongs:songs];
        
        return YES;
    }
}







- (IBAction) renamePlaylist:(id)sender {
    [self selectedPlaylist].title = [sender stringValue];
}

- (void) editPlaylistTitle {
    [self.playlistsTableView editColumn:0
                                    row:[[SDSharedData() playlists] count] - 1
                              withEvent:nil
                                 select:YES];
}










- (void) playerStatusDidChange:(NSNotification*)note {
    [self refreshKeepingCurrentSelection];
}

- (void) currentSongDidChange:(NSNotification*)note {
    [self refreshKeepingCurrentSelection];
}



@end
