/*
  Class implementing screen canvas for Screen preferences

  Author:	Sergii Stoian <stoyan255@ukr.net>
  Date:		2015

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this program; if not, write to:

  Free Software Foundation, Inc.
  59 Temple Place - Suite 330
  Boston, MA  02111-1307, USA
*/
#import <AppKit/AppKit.h>

#import <NXSystem/NXMouse.h>
#import <GNUstepGUI/GSDisplayServer.h>

#import "ScreenCanvas.h"
#import "DisplayBox.h"
#import "Screen.h"

@implementation ScreenCanvas

- initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  [self setBorderType:NSBezelBorder];
  [self setTitlePosition:NSNoTitle];
  [self setFillColor:[NSColor grayColor]];
  [self setContentViewMargins:NSMakeSize(0, 0)];

  isMouseDragged = NO;
  
  return self;
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect:rect];

  [_fill_color set];
  NSRectFill([[self contentView] frame]);

  // [self resetCursorRects];

  // CGFloat f, lines = rect.size.height;
  // CGFloat pattern[2] = {1};
  // [[NSColor darkGrayColor] set];
  // PSsetdash(pattern, 1, 0);
  // for (f=2; f<lines-2; f++)
  //   {
  //     PSmoveto(2, f);
  //     PSlineto(rect.size.width, f);
  //     f++;
  //     PSmoveto(3, f);
  //     PSlineto(rect.size.width-2, f);
  //   }
  // PSstroke();
}

- (void)resetCursorRects
{
  // NSLog(@"ScreenCanvas: resetCursorRects");

  [[self window] discardCursorRects];
  for (NSView *sview in [[self contentView] subviews])
    {
      [self addCursorRect:[sview frame]
                   cursor:[NSCursor openHandCursor]];
    }
}

- (DisplayBox *)lowerBoxForBox:(DisplayBox *)box
{
  NSRect     boxFrame = [box frame];
  DisplayBox *boxUnder = nil;

  for (DisplayBox *db in [[self contentView] subviews])
    {
      if (db == box)
        continue;
      
      if (NSIntersectsRect(boxFrame, [db frame]) == YES)
        {
          boxUnder = db;
          break;
        }
    }

  return boxUnder;
}

- (DisplayBox *)closestBoxForBox:(DisplayBox *)box
{
  NSPoint    closestPoint = NSMakePoint(CGFLOAT_MAX, CGFLOAT_MAX);
  DisplayBox *closestBox = nil;

  for (DisplayBox *db in [[self contentView] subviews])
    {
      if (db == box)
        continue;
      
      if (closestPoint.x > db.frame.origin.x &&
          closestPoint.y > db.frame.origin.y)
        {
          closestPoint = db.frame.origin;
          closestBox = db;
        }
    }

  return closestBox;
}

- (void)slideBox:(DisplayBox *)box initialOrigin:(NSPoint)origin
{
  DisplayBox *closestBox = [self closestBoxForBox:box];

  if (closestBox != nil)
    {
      NSPoint buCPoint = [closestBox centerPoint];
      NSPoint bCPoint = [box centerPoint];
      
      if (bCPoint.x < buCPoint.x)
        {
          if (bCPoint.x < NSMinX(closestBox.frame))
            origin.x = NSMinX(closestBox.frame) - box.frame.size.width;
          else
            origin.x = NSMinX(closestBox.frame);
        }
      else if (bCPoint.x > buCPoint.x)
        {
          if (bCPoint.x > NSMaxX(closestBox.frame))
            origin.x = NSMaxX(closestBox.frame);
          else
            origin.x = NSMaxX(closestBox.frame) - box.frame.size.width;
        }
      
      if (bCPoint.y < buCPoint.y)
        {
          if (bCPoint.y < NSMinY(closestBox.frame))
            origin.y = NSMinY(closestBox.frame) - box.frame.size.height;
          else
            origin.y = NSMinY(closestBox.frame);
        }
      else if (bCPoint.y > buCPoint.y)
        {
          if (bCPoint.y > NSMaxY(closestBox.frame))
            origin.y = NSMaxY(closestBox.frame);
          else
            origin.y = NSMaxY(closestBox.frame) - box.frame.size.height;
        }
    }

  // {
  //   NSBitmapImageRep	*imgRep;
  //   NSImage		*image;

  //   [box lockFocus];
  //   imgRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:[box bounds]];
  //   [box unlockFocus];
  //   image = [[NSImage alloc] initWithData:[imgRep TIFFRepresentation]];

  //   [[NSWorkspace sharedWorkspace]
  //     slideImage:image
  //           from:[self convertRectToBase:box.frame].origin
  //             to:origin];
  //   [imgRep release];
  //   [image release];
  // }

  [box setFrameOrigin:origin];
}

- (void)mouseDown:(NSEvent *)theEvent
            inBox:(DisplayBox *)box
{
  NSWindow   *window = [self window];
  NSRect     canvasFrame = [[self contentView] frame];
  NSRect     boxFrame = [box frame];
  NSPoint    location, initialLocation, lastLocation;
  
  NSPoint    initialOrigin, boxOrigin;
  NSUInteger eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
                          | NSPeriodicMask | NSOtherMouseUpMask
                          | NSRightMouseUpMask);
  NSDate     *theDistantFuture = [NSDate distantFuture];
  BOOL       done = NO;
  NSInteger  moveThreshold;

  initialOrigin = boxOrigin = boxFrame.origin;
  initialLocation = lastLocation = [theEvent locationInWindow];

  moveThreshold = [[[NXMouse new] autorelease] accelerationThreshold];
  [[NSCursor closedHandCursor] push];
  
  [NSEvent startPeriodicEventsAfterDelay:0.02 withPeriod:0.02];

  while (!done)
    {
      theEvent = [NSApp nextEventMatchingMask:eventMask
                                    untilDate:theDistantFuture
                                       inMode:NSEventTrackingRunLoopMode
                                      dequeue:YES];

      switch ([theEvent type])
        {
        case NSRightMouseUp:
        case NSOtherMouseUp:
        case NSLeftMouseUp:
          // NSLog(@"Mouse UP.");
          [self slideBox:box initialOrigin:initialOrigin];
          // Reset mouse cursor to cursor befor mouse down - openHandCursor.
          // TODO: on momentary mouse down/up (without drag) cursor turns
          // into arrowCursor. This is wrong. Perhaps this is due to old and
          // new cursor rects intersection.
          [NSCursor pop];
          [self resetCursorRects];
          [self setNeedsDisplay:YES];
          done = YES;
          break;
        case NSPeriodic:
          location = [window mouseLocationOutsideOfEventStream];
          
          if (!NSPointInRect(location, [self frame]))
            break;
          
          if (NSEqualPoints(location, lastLocation) == NO &&
              (fabs(location.x - initialLocation.x) > moveThreshold ||
               fabs(location.y - initialLocation.y) > moveThreshold))
            {
              // if (displayFrame.origin.x > 0 ||
              //     boxOrigin.x > initialOrigin.x ||
              //     (location.x - lastLocation.x) > 0)
              boxOrigin.x += (location.x - lastLocation.x);
              if (boxOrigin.x < 0)
                {
                  boxOrigin.x = 0;
                }
              else if ((boxOrigin.x + boxFrame.size.width)
                       >= canvasFrame.size.width)
                {
                  boxOrigin.x = canvasFrame.size.width - boxFrame.size.width;
                }
                  
              boxOrigin.y += (location.y - lastLocation.y);
              if (boxOrigin.y < 0)
                {
                  boxOrigin.y = 0;
                }
              else if ((boxOrigin.y + boxFrame.size.height)
                       >= canvasFrame.size.height)
                {
                  boxOrigin.y = canvasFrame.size.height - boxFrame.size.height;
                }
                  
              [box setFrameOrigin:boxOrigin];
              [self setNeedsDisplay:YES];
                  
              lastLocation = location;
            }
          break;

        default:
          break;
        }
    }
  [NSEvent stopPeriodicEvents];

  if (NSEqualPoints(initialLocation, lastLocation) == YES)
    {
      [owner displayBoxClicked:box];
    }
}

@end
