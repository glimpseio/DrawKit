///**********************************************************************************************************************************
///  GCToolPalette.m
///  GCDrawKit
///
///  Created by graham on 11/06/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "GCToolPalette.h"

#import "../../../Source/DKDrawKit.h"


@implementation GCToolPalette
#pragma mark As a GCToolPalette
- (IBAction)	toolButtonMatrixAction:(id) sender
{
	NSCell* cell = [sender selectedCell];
	
//	LogEvent_(kInfoEvent, @"cell = %@, title = %@", cell, [cell title]);
	
	// forward the choice to the first responder - if it implements selectDrawingTool: it will switch tools based
	// on the sender of the message's title matching the registered name of the tool.

	//[NSApp sendAction:@selector(selectDrawingToolByName:) to:nil from:cell];
	
	// another way is to call the -set method on the tool itself:
	
	DKDrawingTool* tool = [cell representedObject];
	[tool set];
}


- (IBAction)	libraryItemAction:(id) sender
{
	// sets the style of the selected tool's prototype to the chosen style. Subsequent drawing with that tool
	// will use the given style.
	
	NSString* key = [[sender representedObject] uniqueKey];
	DKStyle* ss = [DKStyleRegistry styleForKeyAddingToRecentlyUsed:key];
	
	[DKObjectCreationTool setStyleForCreatedObjects:ss];

	NSString* toolname = [[mToolMatrix selectedCell] title];
	DKDrawingTool* tool = [DKDrawingTool drawingToolWithName:toolname];
	[self selectToolWithName:[tool registeredName]];
}


- (IBAction)	toolDoubleClick:(id) sender
{
	// double-clicking a tool turns OFF "auto return to selection". It is turned back on again
	// by manually selecting the selection tool. See DKToolController for details
	
	//	LogEvent_(kInfoEvent, @"dbl-clik tool: %@", sender );
	
	NSString* toolname = [[sender selectedCell] title];
	
	if([toolname isEqualToString:@"Zoom"])
	{
		// return to 100% zoom
		
		[NSApp sendAction:@selector(zoomToActualSize:) to:nil from:sender];
	}
	else
	{
		[NSApp sendAction:@selector(toggleAutoRevertAction:) to:nil from:sender];
	}
}

#pragma mark -
- (void)		selectToolWithName:(NSString*) name
{
	int				row, col, rr, cc;
	NSCell*			cell;
	DKStyle* style = [DKObjectCreationTool styleForCreatedObjects];
	
	[mToolMatrix getNumberOfRows:&row columns:&col];
	
	for( rr = 0; rr < row; ++rr )
	{
		for( cc = 0; cc < col; ++cc )
		{
			cell = [mToolMatrix cellAtRow:rr column:cc];
			
			if([[cell title] isEqualToString:name])
			{
				[mToolMatrix selectCellAtRow:rr column:cc];
				
				// set the preview image to the tool prototype's style, if any
				
				DKDrawingTool* tool = [DKDrawingTool drawingToolWithName:name];
				
				if ( tool && [tool isKindOfClass:[DKObjectCreationTool class]] )
				{
					if ( style == nil )
						style = [(DKDrawableObject*)[(DKObjectCreationTool*)tool prototype] style];
						
					
				}
				
				[self updateStylePreviewWithStyle:style];
				return;
			}
		}
	}
	
	[mToolMatrix selectCellAtRow:0 column:0];
	[self updateStylePreviewWithStyle:style];
}


- (void)		toolChangedNotification:(NSNotification*) note
{
#pragma unused (note)
	DKToolController*	tc = [note object];
	NSString*			tn = [[tc drawingTool] registeredName];
	
//	LogEvent_( kReactiveEvent, @"tool did change to '%@'", tn );
	
	if ( tn == nil )
		tn = @"Select";
	
	[self selectToolWithName:tn];
}


- (void)		populatePopUpButtonWithLibraryStyles:(NSPopUpButton*) button
{
	NSMenu* styleMenu = [DKStyleRegistry managedStylesMenuWithItemTarget:self itemAction:@selector(libraryItemAction:)];
	[button setMenu:styleMenu];
	[button setTitle:@"Style"];
}


- (void)		updateStylePreviewWithStyle:(DKStyle*) style
{
	NSImage* swatch = [[style styleSwatchWithSize:NSMakeSize( 112, 112 ) type:kDKStyleSwatchAutomatic] copy];
	[mStylePreviewView setImage:swatch];
	[swatch release];
}


- (void)		styleRegistryChanged:(NSNotification*) note
{
#pragma unused (note)
	[self populatePopUpButtonWithLibraryStyles:mStylePopUpButton];
}



#pragma mark -
#pragma mark As an DKDrawkitInspectorBase
- (void)				documentDidChange:(NSNotification*) note
{
	NSResponder* firstR = [[note object] firstResponder];
	
	if( firstR != nil && [firstR respondsToSelector:@selector(drawingTool)])
	{
		DKDrawingTool*	tool = [(id)firstR drawingTool];
		NSString*		tn = [tool registeredName];
	
//		LogEvent_( kReactiveEvent, @"tool will change to '%@'", tn );
	
		if ( tn == nil )
			tn = @"Select";
	
		[self selectToolWithName:tn];
	}
}

#pragma mark -
#pragma mark As an NSWindowController
- (void)		windowDidLoad
{
	[(NSPanel*)[self window] setFloatingPanel:YES];
	[(NSPanel*)[self window] setBecomesKeyOnlyIfNeeded:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toolChangedNotification:) name:kDKDidChangeToolNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(styleRegistryChanged:) name:kDKStyleRegistryDidFlagPossibleUIChange object:[DKStyleRegistry sharedStyleRegistry]];

	// set up button cells with the respective images - the cell title is used to look up the image resource
	
	NSEnumerator*	iter = [[mToolMatrix cells] objectEnumerator];
	NSActionCell*	cell;
	NSImage*		icon;
	
	while ( (cell = (NSActionCell*)[iter nextObject]) != nil)
	{
		icon = [NSImage imageNamed:[cell title]];
		
		if ( icon )
			[cell setImage:icon];
			
		if ([[cell title] length] == 0)
			[cell setEnabled:NO];
		else
		{	
			DKDrawingTool* tool = [DKDrawingTool drawingToolWithName:[cell title]];
			[cell setRepresentedObject:tool];
			[mToolMatrix setToolTip:[cell title] forCell:cell];
		}
	}
	
	[self populatePopUpButtonWithLibraryStyles:mStylePopUpButton];
	[mToolMatrix setDoubleAction:@selector(toolDoubleClick:)];
	
	// position the palette on the left of the main screen

	NSRect panelFrame = [[self window] frame];
	NSRect screenFrame = [[[NSScreen screens] objectAtIndex:0] visibleFrame];
	
	panelFrame.origin.x = NSMinX( screenFrame ) + 34;
	panelFrame.origin.y = NSHeight( screenFrame ) - 20 - NSHeight( panelFrame ); 
	[[self window] setFrameOrigin:panelFrame.origin];
}


#pragma mark -


- (BOOL)			validateMenuItem:(NSMenuItem*) item
{
	SEL action = [item action];
	
	if( action == @selector(libraryItemAction:))
	{
		[item setState:[DKObjectCreationTool styleForCreatedObjects] == [item representedObject]? NSOnState : NSOffState];
	}
	
	return YES;
}


@end
