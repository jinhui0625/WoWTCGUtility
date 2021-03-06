/*
 Copyright (c) 2010 Mike Chambers
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "ArrayPredicateEditorRowTemplate.h"


@implementation ArrayPredicateEditorRowTemplate

-(void)dealloc
{
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain]; //we are immutable
}

//designated constructor
-(id)initWithArray:(NSArray *)arr forKeyPath:(NSString *)keyPath andTitle:(NSString *)title withOperators:(NSArray *)operators
{	
	NSMutableArray *expressions = [NSMutableArray arrayWithCapacity:[arr count]];
	for(NSString *s in arr)
	{
		[expressions addObject:[NSExpression expressionForConstantValue:s]];
	}	
	
	if(!(self = [super initWithLeftExpressions:[NSArray arrayWithObjects:[NSExpression expressionForKeyPath:keyPath], nil]
					  rightExpressions:expressions
							  modifier:NSDirectPredicateModifier
							 operators:operators
							   options:NSCaseInsensitivePredicateOption
		 ]))
	{
		return nil;
	}
	
	NSPopUpButton *popup = [[super templateViews] objectAtIndex:0];
	NSMenuItem *item = [popup itemAtIndex:0];
	item.title = title;
	
	return self;
}

@end
