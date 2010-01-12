//
//  CardImage.h
//  WoWTCGUtility
//
//  Created by Mike Chambers on 1/12/10.
//  Copyright 2010 Mike Chambers. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Card.h"

@interface CardImageView : NSImageView
{
	Card *card;
	BOOL enableClick;
}

@property (retain) Card *card;
@property (assign) BOOL enableClick;


-(void)displayCard;

@end